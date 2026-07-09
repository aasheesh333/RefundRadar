import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/firestore_dispute_repository.dart';
import 'package:refund_radar/data/repositories/reminder_repository.dart';
import 'package:refund_radar/services/notification_service.dart';

final disputeRepositoryProvider =
    Provider<FirestoreDisputeRepository>((ref) {
  // Wire the cross-repo cascade: deleting a dispute (or all user data) also
  // wipes reminders + cancels local notifications. Kept in the provider so
  // the repository itself stays repo-agnostic; the cascade lives at the
  // composition root. All failures inside the cascade are best-effort and
  // are logged (see firestore_dispute_repository.dart).
  return FirestoreDisputeRepository(
    onDeleteDispute: (uid, disputeId) async {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      try {
        await reminderRepo.deleteForDispute(uid, disputeId);
      } catch (_) {/* logged upstream */}
      try {
        await ref.read(notificationServiceProvider).cancelForDispute(disputeId);
      } catch (_) {/* logged upstream */}
    },
    onDeleteAllUserData: (uid) async {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      try {
        await reminderRepo.deleteAllUserData(uid);
      } catch (_) {/* logged upstream */}
      try {
        await ref.read(notificationServiceProvider).cancelAll();
      } catch (_) {/* logged upstream */}
    },
  );
});

final disputesProvider =
    FutureProvider.family<List<Dispute>, String>((ref, uid) async {
  final repo = ref.watch(disputeRepositoryProvider);
  return repo.loadDisputes(uid);
});
