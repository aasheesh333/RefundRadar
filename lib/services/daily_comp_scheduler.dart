import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_state_provider.dart';
import 'notification_service.dart';

class DailyCompScheduler {
  final NotificationService _notifications;

  DailyCompScheduler(this._notifications);

  /// Schedules a daily 9 AM notification if dailyComp is enabled.
  /// Called on app start and when notifDailyProvider toggles.
  Future<void> schedule(WidgetRef ref, String uid) async {
    final enabled = ref.read(notifDailyProvider);
    if (!enabled) {
      await _notifications.cancelDailyComp();
      return;
    }
    await _notifications.scheduleDailyComp();
  }
}
