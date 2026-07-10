import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/models/reminder.dart';
import 'package:refund_radar/data/repositories/reminder_generator.dart';
import 'package:refund_radar/services/notification_service.dart';

abstract class ReminderRepository {
  Future<List<Reminder>> loadReminders(String uid);
  Future<void> syncForDispute(String uid, Dispute dispute);
  Future<void> dismiss(String uid, String reminderId);
  Future<void> deleteForDispute(String uid, String disputeId);
  Future<void> deleteAllUserData(String uid);
}

class FirestoreReminderRepository implements ReminderRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const ReminderGenerator _generator = ReminderGenerator();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('reminders');

  /// Mirror of `FirestoreDisputeRepository._ensureAuthToken`: make sure Auth
  /// has a current user + ID token before any Firestore call. Prevents the
  /// classic cold-boot race where the UI holds a uid but `request.auth` is
  /// still null on the server → `permission-denied`.
  Future<void> _ensureAuthToken(String uid) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || user.uid != uid) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message:
            'Not signed in as $uid (current=${user?.uid}). Re-authenticate.',
      );
    }
    await user.getIdToken();
  }

  /// Cold-boot race fix (ported from the dispute repo). On a fresh anonymous
  /// sign-in the client holds a valid ID token before Firestore's server-side
  /// `request.auth` is populated. Retry with backoff + force a fresh token
  /// between attempts.
  Future<T> _withAuthRetry<T>(
    String uid,
    String label,
    Future<T> Function() op, {
    int maxAttempts = 4,
    List<Duration> delays = const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1200),
      Duration(seconds: 3),
    ],
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await op();
      } on FirebaseException catch (e) {
        lastError = e;
        debugPrint('$label attempt ${attempt + 1} failed: ${e.code} ${e.message}');
        final retriable = e.code == 'permission-denied' ||
            e.code == 'unauthenticated';
        if (!retriable || attempt == maxAttempts - 1) rethrow;
        try {
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (_) {/* ignore */}
        await Future.delayed(delays[attempt]);
      }
    }
    throw lastError ?? StateError('$label exhausted retries for $uid');
  }

  @override
  Future<List<Reminder>> loadReminders(String uid) async {
    await _ensureAuthToken(uid);
    return _withAuthRetry<List<Reminder>>(uid, 'loadReminders', () async {
      final snap = await _col(uid).orderBy('fireAt').get();
      return snap.docs
          .map((d) => Reminder.fromJson(d.data()..['id'] = d.id))
          .toList();
    });
  }

  /// Idempotent upsert: deletes reminders for [dispute] that are no longer
  /// applicable, then writes the desired set to Firestore. Local notification
  /// scheduling is the caller's responsibility (`syncRemindersForDispute`)
  /// so this method stays atomic on the Firestore side only.
  @override
  Future<void> syncForDispute(String uid, Dispute dispute) async {
    await _ensureAuthToken(uid);
    await _withAuthRetry<void>(uid, 'syncForDispute', () async {
      final desired = _generator.forDispute(dispute);
      final desiredIds = desired.map((r) => r.id).toSet();

      final existing =
          await _col(uid).where('disputeId', isEqualTo: dispute.id).get();
      final batch = _db.batch();
      for (final doc in existing.docs) {
        final id = doc.data()['id'] as String? ?? doc.id;
        if (!desiredIds.contains(id)) {
          batch.delete(doc.reference);
        }
      }
      for (final r in desired) {
        final ref = _col(uid).doc(r.id);
        batch.set(ref, r.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
    });
  }

  @override
  Future<void> dismiss(String uid, String reminderId) async {
    await _ensureAuthToken(uid);
    await _withAuthRetry<void>(uid, 'dismiss', () async {
      await _col(uid).doc(reminderId).update({'dismissed': true});
    });
  }

  @override
  Future<void> deleteForDispute(String uid, String disputeId) async {
    await _ensureAuthToken(uid);
    await _withAuthRetry<void>(uid, 'deleteForDispute', () async {
      final snap =
          await _col(uid).where('disputeId', isEqualTo: disputeId).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    });
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    await _ensureAuthToken(uid);
    await _withAuthRetry<void>(uid, 'deleteAllUserData', () async {
      final snap = await _col(uid).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    });
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return FirestoreReminderRepository();
});

/// Live stream of the signed-in user's reminders, sorted by [fireAt].
final remindersProvider = StreamProvider.family<List<Reminder>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('reminders')
      .orderBy('fireAt')
      .snapshots()
      .map((qs) => qs.docs.map((d) => Reminder.fromJson(d.data()..['id'] = d.id)).toList());
});

/// Pure helper used by `syncRemindersForDispute` + `deleteRemindersForDispute`
/// to compute the full set of reminder IDs that could ever exist for a
/// given dispute. Reminder IDs follow the deterministic pattern
/// `'<disputeId>_<stage.id>'` (see `Reminder.id` + `ReminderGenerator._make`),
/// so this is the exhaustive union — no extra Firestore round-trip needed.
/// Returning every possible id lets us cancel stale notifications without
/// needing a snapshot of what was scheduled previously, which closes the
/// previous bug where `NotificationService` derived the local-notification
/// id from `disputeId.hashCode` only and `zonedSchedule` calls for the same
/// dispute collided onto a single slot.
List<String> allReminderIdsForDispute(String disputeId) {
  return ReminderStage.values.map((s) => '${disputeId}_${s.id}').toList();
}

/// Sync reminders for a dispute AND schedule their local notifications.
/// Call this from dispute_create + dispute_detail whenever the lifecycle
/// stage changes.
///
/// Atomicity contract: the Firestore batch is committed FIRST via
/// `repo.syncForDispute`. Local notifications are then scheduled
/// individually with per-reminder try/catch — one failure doesn't abort the
/// others. If a notification can't be scheduled the underlying reminder row
/// still exists with its `fireAt`, so a future `NotificationRepairService`
/// (or a re-sync triggered by re-opening the dispute) can re-arm it.
Future<void> syncRemindersForDispute(dynamic ref, String uid, Dispute dispute) async {
  final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;
  await repo.syncForDispute(uid, dispute);

  final notifications = ref.read(notificationServiceProvider) as NotificationService;
  await notifications.cancelForDispute(allReminderIdsForDispute(dispute.id));
  final deadlinesOn = ref.read(notifDeadlineProvider) as bool? ?? true;
  if (!deadlinesOn) return;
  for (final r in const ReminderGenerator().forDispute(dispute)) {
    try {
      await notifications.scheduleDeadlineReminder(
        reminderId: r.id,
        title: r.title,
        body: r.body,
        fireAt: r.fireAt,
      );
    } catch (e, st) {
      // Don't lose the whole reminder set because one scheduling call threw.
      debugPrint('scheduleDeadlineReminder failed for ${r.id}: $e\n$st');
    }
  }
}

/// Re-arm local notifications for all future, non-dismissed reminders.
/// Call after cold start / reboot so OS-cleared alarms return.
Future<void> repairScheduledNotifications(dynamic ref, String uid) async {
  final deadlinesOn = ref.read(notifDeadlineProvider) as bool? ?? true;
  if (!deadlinesOn) return;
  try {
    final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;
    final all = await repo.loadReminders(uid);
    final now = DateTime.now();
    final notifications =
        ref.read(notificationServiceProvider) as NotificationService;
    for (final r in all) {
      if (r.dismissed == true) continue;
      if (!r.fireAt.isAfter(now)) continue;
      try {
        await notifications.scheduleDeadlineReminder(
          reminderId: r.id,
          title: r.title,
          body: r.body,
          fireAt: r.fireAt,
        );
      } catch (e, st) {
        debugPrint('repair schedule failed for ${r.id}: $e\n$st');
      }
    }
  } catch (e, st) {
    debugPrint('repairScheduledNotifications failed: $e\n$st');
  }
}

/// Reverse of `syncRemindersForDispute`: delete all reminder rows for a
/// dispute AND cancel their local notifications. Best-effort on both sides
/// — a Firestore failure still attempts notifications cleanup (logged) and
/// vice-versa — so a partial failure doesn't leave one half orphaned.
Future<void> deleteRemindersForDispute(dynamic ref, String uid, String disputeId) async {
  final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;
  try {
    await repo.deleteForDispute(uid, disputeId);
  } catch (e, st) {
    debugPrint('deleteForDispute Firestore failed for $disputeId: $e\n$st');
  }
  try {
    final notifications =
        ref.read(notificationServiceProvider) as NotificationService;
    await notifications.cancelForDispute(allReminderIdsForDispute(disputeId));
  } catch (_) {
    // Last-ditch cleanup: if we somehow failed to enumerate the per-stage
    // ids (shouldn't happen — it's a pure local computation), blow away
    // every scheduled notification so a deleted dispute doesn't leave
    // orphan alarms pinned to the OS scheduler.
    try {
      await ref.read(notificationServiceProvider).cancelAll();
    } catch (e, st) {
      debugPrint('cancelAll notifications failed for $disputeId: $e\n$st');
    }
  }
}

/// Delete ALL reminders + cancel ALL scheduled notifications for a user.
/// Called from Settings → "Delete data" before the dispute list + user doc
/// are wiped. Best-effort on both halves.
Future<void> deleteAllRemindersAndNotifications(dynamic ref, String uid) async {
  final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;
  try {
    await repo.deleteAllUserData(uid);
  } catch (e, st) {
    debugPrint('deleteAllUserData reminders failed for $uid: $e\n$st');
  }
  try {
    final notifications =
        ref.read(notificationServiceProvider) as NotificationService;
    await notifications.cancelAll();
  } catch (e, st) {
    debugPrint('cancelAll notifications failed for $uid: $e\n$st');
  }
}
