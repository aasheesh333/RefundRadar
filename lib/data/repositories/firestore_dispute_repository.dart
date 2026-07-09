import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:refund_radar/data/models/dispute.dart';

abstract class DisputeRepository {
  Future<List<Dispute>> loadDisputes(String uid);
  Future<Dispute> saveDispute(String uid, Dispute dispute);
  Future<void> deleteDispute(String uid, String id);
  Future<void> deleteAllUserData(String uid);
}

class FirestoreDisputeRepository implements DisputeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('disputes');

  /// Make sure Auth has a current user + ID token before any Firestore call.
  /// Prevents the classic race where the UI has a uid but `request.auth` is
  /// still null on the server → `permission-denied`.
  Future<void> _ensureAuthToken(String uid) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || user.uid != uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'Not signed in as $uid (current=${user?.uid}). Tap Retry to re-authenticate.',
      );
    }
    await user.getIdToken();
  }

  /// Ensure the parent `users/{uid}` doc exists. Some Firebase project setups
  /// (and future rule tightenings) expect the user root to be present; it's
  /// cheap and idempotent.
  Future<void> _ensureUserDoc(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Cold-boot race fix. On a fresh anonymous sign-in the client holds a
  /// valid ID token before Firestore's server-side `request.auth` is
  /// populated. The first `get()` therefore bounces with
  /// `permission-denied` and surfaces the "Could not load your disputes"
  /// error banner (bugs/Screenshot 12-12-33). A short retry with backoff
  /// lets the token propagate (typically <1.5 s) and the read succeeds.
  Future<List<Dispute>> _loadDisputesWithRetry(String uid) async {
    const maxAttempts = 4;
    const delays = [Duration(milliseconds: 500),
                    Duration(milliseconds: 1200),
                    Duration(seconds: 3)];
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _ensureUserDoc(uid);
        final snap =
            await _col(uid).orderBy('createdAt', descending: true).get();
        return snap.docs
            .map((d) => Dispute.fromJson(d.data()..['id'] = d.id))
            .toList();
      } on FirebaseException catch (e) {
        lastError = e;
        debugPrint('loadDisputes attempt ${attempt + 1} failed: '
            '${e.code} ${e.message}');
        // Only retry the auth/token race (`permission-denied` /
        // `unauthenticated`). Other errors surface immediately.
        final retriable = e.code == 'permission-denied' ||
            e.code == 'unauthenticated';
        // Fallback: retry without orderBy (failed-precondition ≈ missing
        // index / empty-collection edge). Fire-and-forget correction, then
        // return the cleaned list.
        if (e.code == 'failed-precondition') {
          final snap = await _col(uid).get();
          final list = snap.docs
              .map((d) => Dispute.fromJson(d.data()..['id'] = d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }
        if (!retriable || attempt == maxAttempts - 1) rethrow;
        // Force a fresh token before the next attempt to refresh
        // `request.auth` on the server.
        try {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (_) {/* ignore */}
        await Future.delayed(delays[attempt]);
      }
    }
    throw lastError ?? StateError('loadDisputes exhausted retries for $uid');
  }

  @override
  Future<List<Dispute>> loadDisputes(String uid) async {
    await _ensureAuthToken(uid);
    return _loadDisputesWithRetry(uid);
  }

  @override
  Future<Dispute> saveDispute(String uid, Dispute dispute) async {
    await _ensureAuthToken(uid);
    await _ensureUserDoc(uid);
    final data = dispute.toJson()..['uid'] = uid;
    if (dispute.id.isEmpty) {
      final ref = await _col(uid).add(data);
      return dispute.copyWith(id: ref.id, uid: uid);
    }
    await _col(uid).doc(dispute.id).set(data, SetOptions(merge: true));
    return dispute.copyWith(uid: uid);
  }

  @override
  Future<void> deleteDispute(String uid, String id) async {
    await _ensureAuthToken(uid);
    await _col(uid).doc(id).delete();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    await _ensureAuthToken(uid);
    final snap = await _col(uid).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _db.collection('users').doc(uid).delete();
  }
}
