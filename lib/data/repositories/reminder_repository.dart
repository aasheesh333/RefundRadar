import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Future<List<Reminder>> loadReminders(String uid) async {
    final snap = await _col(uid).orderBy('fireAt').get();
    return snap.docs.map((d) => Reminder.fromJson(d.data()..['id'] = d.id)).toList();
  }

  /// Idempotent upsert: deletes reminders for [dispute] that are no longer
  /// applicable, schedules new ones via the [NotificationService], and
  /// writes the resulting set to Firestore.
  @override
  Future<void> syncForDispute(String uid, Dispute dispute) async {
    final desired = _generator.forDispute(dispute);
    final desiredIds = desired.map((r) => r.id).toSet();

    final existing = await _col(uid).where('disputeId', isEqualTo: dispute.id).get();
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
  }

  @override
  Future<void> dismiss(String uid, String reminderId) async {
    await _col(uid).doc(reminderId).update({'dismissed': true});
  }

  @override
  Future<void> deleteForDispute(String uid, String disputeId) async {
    final snap = await _col(uid).where('disputeId', isEqualTo: disputeId).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final snap = await _col(uid).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
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

/// Sync reminders for a dispute AND schedule their local notifications.
/// Call this from dispute_create + dispute_detail whenever the lifecycle
/// stage changes.
Future<void> syncRemindersForDispute(dynamic ref, String uid, Dispute dispute) async {
  final repo = ref.read(reminderRepositoryProvider) as ReminderRepository;
  await repo.syncForDispute(uid, dispute);

  final notifications = ref.read(notificationServiceProvider) as NotificationService;
  await notifications.cancelForDispute(dispute.id);
  for (final r in const ReminderGenerator().forDispute(dispute)) {
    await notifications.scheduleDeadlineReminder(
      disputeId: dispute.id,
      title: r.title,
      body: r.body,
      fireAt: r.fireAt,
    );
  }
}
