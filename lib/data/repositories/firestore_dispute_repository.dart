import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:refund_radar/data/models/activity_log_entry.dart';
import 'package:refund_radar/data/models/dispute.dart';

abstract class DisputeRepository {
  Future<List<Dispute>> loadDisputes(String uid);
  Future<List<Dispute>> syncExpiredStatuses(String uid, List<Dispute> current, DateTime now);
  Future<Dispute> saveDispute(String uid, Dispute dispute);
  Future<void> deleteDispute(String uid, String id);
  Future<void> deleteAllUserData(String uid);
}

class FirestoreDisputeRepository implements DisputeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Optional cascade hook invoked AFTER a single dispute is deleted. The
  /// provider layer wires this to delete the dispute's reminders + cancel
  /// its local notifications. Failures inside the hook are logged and do
  /// NOT un-delete the dispute — orphaned reminders are harmless (next sync
  /// re-validates them).
  final Future<void> Function(String uid, String disputeId)? onDeleteDispute;

  /// Optional cascade hook invoked AFTER all the user's disputes are
  /// deleted by `deleteAllUserData`. Provider wires this to wipe the
  /// reminder subcollection + cancel ALL scheduled local notifications.
  final Future<void> Function(String uid)? onDeleteAllUserData;

  FirestoreDisputeRepository({
    this.onDeleteDispute,
    this.onDeleteAllUserData,
  });

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
    const delays = [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1200),
      Duration(seconds: 3),
    ];
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _ensureAuthToken(uid);
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
        final retriable =
            e.code == 'permission-denied' || e.code == 'unauthenticated';
        if (e.code == 'failed-precondition') {
          final snap = await _col(uid).get();
          final list = snap.docs
              .map((d) => Dispute.fromJson(d.data()..['id'] = d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }
        if (!retriable || attempt == maxAttempts - 1) rethrow;
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
    // Auth token check lives inside the retry loop so a cold-boot race
    // (uid known, request.auth still null) gets the same backoff as reads.
    final loaded = await _loadDisputesWithRetry(uid);
    return syncExpiredStatuses(uid, loaded, DateTime.now());
  }

  Future<T> _withAuthRetry<T>(String uid, Future<T> Function() action) async {
    const maxAttempts = 4;
    const delays = [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1200),
      Duration(seconds: 3),
    ];
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _ensureAuthToken(uid);
        await _ensureUserDoc(uid);
        return await action();
      } on FirebaseException catch (e) {
        lastError = e;
        debugPrint(
            'withAuthRetry attempt ${attempt + 1} failed: ${e.code} ${e.message}');
        final retriable =
            e.code == 'permission-denied' || e.code == 'unauthenticated';
        if (!retriable || attempt == maxAttempts - 1) rethrow;
        try {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (_) {/* ignore */}
        await Future.delayed(delays[attempt]);
      }
    }
    throw lastError ?? StateError('withAuthRetry exhausted for $uid');
  }

  /// Tracks dispute ids currently being expired so a rapid rebuild doesn't
  /// enqueue multiple writes for the same document.
  final _expiringInFlight = <String>{};

  /// Returns the input list with any inactivity-expired disputes updated to
  /// [DisputeStatus.expired] and persisted to Firestore. Expiry is computed
  /// against [now] and is idempotent per app session.
  @override
  Future<List<Dispute>> syncExpiredStatuses(
    String uid,
    List<Dispute> current,
    DateTime now,
  ) async {
    final expired = <Dispute>[];
    final toWrite = <Dispute>[];
    for (final d in current) {
      if (d.shouldAutoExpire(now) && !_expiringInFlight.contains(d.id)) {
        _expiringInFlight.add(d.id);
        final updated = d.copyWith(
          status: DisputeStatus.expired,
          activityLog: [
            ...d.activityLog,
            ActivityLogEntry(
              type: ActivityLogEntry.disputeExpired,
              label: 'Dispute expired after 90 days of inactivity',
              meta: '',
              timestamp: now,
              highlighted: false,
            ),
          ],
        );
        toWrite.add(updated);
        expired.add(updated);
      } else {
        expired.add(d);
      }
    }
    for (final d in toWrite) {
      try {
        await saveDispute(uid, d);
      } catch (e) {
        debugPrint('syncExpiredStatuses write failed: $e');
      } finally {
        _expiringInFlight.remove(d.id);
      }
    }
    return expired;
  }

  @override
  Future<Dispute> saveDispute(String uid, Dispute dispute) async {
    // Generate the document reference ONCE, before the retry loop, so
    // that all retry attempts write to the same doc id. This makes
    // `set()` idempotent — a network-retry or crash-recovery replay
    // overwrites the same doc instead of creating duplicates.
    final isNew = dispute.id.isEmpty;
    final docRef = isNew ? _col(uid).doc() : _col(uid).doc(dispute.id);
    final id = docRef.id;
    return _withAuthRetry(uid, () async {
      final data = dispute.toJson()..['uid'] = uid;
      await docRef.set(data, SetOptions(merge: true));
      return dispute.copyWith(id: id, uid: uid);
    });
  }

  @override
  Future<void> deleteDispute(String uid, String id) async {
    await _ensureAuthToken(uid);
    // Cascade FIRST: wipe reminders + cancel local notifications BEFORE
    // deleting the parent dispute. If the cascade fails, the parent is
    // still alive — the user can retry. Deleting the parent first would
    // orphan reminders that can't be tracked back to a deleted dispute.
    if (onDeleteDispute != null) {
      await onDeleteDispute!(uid, id);
    }
    await _col(uid).doc(id).delete();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    await _ensureAuthToken(uid);
    // Cascade FIRST: delete the reminders subcollection + cancel all
    // scheduled notifications while the user doc still exists (rules
    // require `isOwner(uid)`, so the token must still be valid here).
    if (onDeleteAllUserData != null) {
      await onDeleteAllUserData!(uid);
    }
    final snap = await _col(uid).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _db.collection('users').doc(uid).delete();
  }
}
