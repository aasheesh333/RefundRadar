import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Ensures an anonymous Firebase user exists and that a fresh ID token is
/// available before Firestore/Storage calls run. Without the token refresh,
/// the first Firestore read can race auth and return `permission-denied`
/// even though Anonymous sign-in is enabled.
Future<User?> ensureAnonymousUser(FirebaseAuth auth) async {
  try {
    return await Future(() async {
      var user = auth.currentUser;
      if (user == null) {
        final cred = await auth.signInAnonymously();
        user = cred.user;
      }
      // Force a token so subsequent Firestore requests carry request.auth.
      await user?.getIdToken(true);
      return user;
    }).timeout(const Duration(seconds: 12));
  } catch (e, st) {
    debugPrint('ensureAnonymousUser failed: $e\n$st');
    return null;
  }
}

/// Live uid stream. Boots with an ensured anonymous session, then tracks
/// [authStateChanges]. Yields `null` only when sign-in truly fails (no
/// network / Anonymous provider disabled).
final userIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);

  // Immediate ensure so the first frame that needs a uid doesn't wait only
  // on authStateChanges (which can lag behind configure).
  final boot = await ensureAnonymousUser(auth);
  if (boot != null) {
    yield boot.uid;
  } else {
    yield null;
  }

  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      final again = await ensureAnonymousUser(auth);
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
final reauthProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final auth = ref.read(firebaseAuthProvider);
    // Sign out stale session then re-anon — clears a bad/expired token.
    try {
      if (auth.currentUser != null) {
        await auth.signOut();
      }
    } catch (_) {/* ignore */}
    final user = await ensureAnonymousUser(auth);
    return user?.uid;
  };
});
