import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzName = await _resolveLocalTzName();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('tz setLocalLocation failed, falling back: $e');
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);
  }

  Future<String> _resolveLocalTzName() async {
    return tz.local.name;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static int scheduledIdFor(String reminderId) {
    return reminderId.hashCode & 0x7FFFFFFF;
  }

  static int cancelIdFor(String reminderId) {
    return scheduledIdFor(reminderId);
  }

  Future<int> scheduleDeadlineReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    final id = scheduledIdFor(reminderId);
    final androidDetails = AndroidNotificationDetails(
      'refund_radar_deadlines',
      'Dispute deadlines',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return id;
  }

  Future<void> cancelForReminder(String reminderId) async {
    final id = cancelIdFor(reminderId);
    await _plugin.cancel(id);
  }

  Future<void> cancelForDispute(List<String> reminderIds) async {
    for (final reminderId in reminderIds) {
      await cancelForReminder(reminderId);
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
