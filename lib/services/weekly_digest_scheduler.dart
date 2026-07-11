import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_state_provider.dart';
import 'notification_service.dart';

class WeeklyDigestScheduler {
  final NotificationService _notifications;

  WeeklyDigestScheduler(this._notifications);

  Future<void> schedule(WidgetRef ref, String uid) async {
    final enabled = ref.read(notifWeeklyProvider);
    if (!enabled) {
      await _notifications.cancelWeeklyDigest();
      return;
    }
    await _notifications.scheduleWeeklyDigest();
  }
}
