import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:refund_radar/services/revenue_cat_service.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Last anonymous sign-in failure reason. Populated by
/// [ensureAnonymousUser] when `signInAnonymously()` throws (e.g. the
/// Anonymous provider is disabled in Firebase Console). Cleared on the next
/// successful boot. Exposed separately so the Home error banner can show
/// the exact failing layer (auth vs rules vs network) without restructuring
/// the uid stream's null-vs-error semantics.
final lastAuthErrorProvider = StateProvider<String?>((ref) => null);

/// Ensures an anonymous Firebase user exists and that a fresh ID token is
/// available before Firestore/Storage calls run. Without the token refresh,
/// the first Firestore read can race auth and return `permission-denied`
/// even though Anonymous sign-in is enabled.
///
/// After a successful auth, best-effort links RevenueCat to the Firebase
/// uid via [RevenueCatService.syncWithFirebaseUid] — fire-and-forget so
/// startup / re-auth never block on RC identity.
Future<User?> ensureAnonymousUser(FirebaseAuth auth, {Ref? ref}) async {
  // Step 1 — obtain an anonymous user. signInAnonymously() itself returns a
  // valid ID token, so the forced refresh below is best-effort, not the
  // gate that decides whether the user "exists" for the UI.
  User? user = auth.currentUser;
  if (user == null) {
    try {
      final cred = await auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 12));
      user = cred.user;
    } catch (e, st) {
      debugPrint('ensureAnonymousUser: signInAnonymously failed: $e\n$st');
      ref?.read(lastAuthErrorProvider.notifier).state = e.toString();
      return null;
    }
  }

  // Step 2 — best-effort token refresh. The forced refresh ensures the
  // refreshed JWT is available to Firestore calls so the first read does
  // not race auth and return permission-denied. BUT if the refresh hangs
  // (slow/hot path to securetoken.googleapis.com), we must NOT throw away
  // the already-signed-in user — they still have a short-lived token from
  // signInAnonymously(). Fire the force-refresh in the background; if it
  // fails the existing Firestore read retry path will recover.
  if (user != null) {
    unawaited(
      user
          .getIdToken(true)
          .timeout(const Duration(seconds: 6))
          .catchError((Object e) {
        debugPrint('ensureAnonymousUser: getIdToken(true) skipped: $e');
      }),
    );
  }

  // Success — clear any stale auth error so the banner doesn't keep
  // surfacing a fixed-then-retried condition.
  ref?.read(lastAuthErrorProvider.notifier).state = null;

  final uid = user?.uid;
  if (uid != null && ref != null) {
    unawaited(
      ref
          .read(revenueCatServiceProvider)
          .syncWithFirebaseUid(uid)
          .catchError((Object e) {
        debugPrint('RevenueCat uid sync skipped: $e');
      }),
    );
  }
  return user;
}

/// Live uid stream. Boots with an ensured anonymous session, then tracks
/// [authStateChanges]. Yields `null` only when sign-in truly fails (no
/// network / Anonymous provider disabled).
final userIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  // Immediate ensure so the first frame that needs a uid doesn't wait only
  // on authStateChanges (which can lag behind configure).
  final boot = await ensureAnonymousUser(auth, ref: ref);
  if (boot != null) {
    yield boot.uid;
  } else {
    yield null;
  }

  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      final again = await ensureAnonymousUser(auth, ref: ref);
      yield again?.uid;
    } else {
      // Keep token warm on auth events (refresh / restore).
      try {
        await user.getIdToken();
      } catch (_) {/* ignore */}
      yield user.uid;
    }
  }
});

/// Explicit re-auth helper for Retry buttons on permission-denied screens.
/// Does NOT signOut first — that would discard a successfully-obtained
/// anonymous user and force a fresh signInAnonymously() round-trip that
/// may itself be slow/failing. Instead just re-runs ensureAnonymousUser,
/// which short-circuits to the cached user if one exists.
final reauthProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final auth = ref.read(firebaseAuthProvider);
    final user = await ensureAnonymousUser(auth, ref: ref);
    return user?.uid;
  };
});
