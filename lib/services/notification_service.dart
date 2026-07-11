import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const _kPrefMigratedFnv1aIds = 'migrated_fnv1a_ids';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('tz setLocalLocation failed: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (e2) {
        debugPrint('tz setLocalLocation failed: $e2');
      }
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static int scheduledIdFor(String reminderId) {
    var hash = 0x811c9dc5;
    for (final byte in reminderId.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
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

  static const _dailyCompNotificationId = 9001;

  Future<void> scheduleDailyComp() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _dailyCompNotificationId,
      'Daily compensation summary',
      'Tap to see how much penalty has accrued across your disputes',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_comp_channel',
          'Daily compensation summary',
          channelDescription: 'Daily summary of penalty compensation accrued',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyComp() async {
    await _plugin.cancel(_dailyCompNotificationId);
  }

  static const _weeklyDigestNotificationId = 9002;

  Future<void> scheduleWeeklyDigest() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    await _plugin.zonedSchedule(
      _weeklyDigestNotificationId,
      'Weekly dispute digest',
      'Tap to see your dispute activity this week',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_digest_channel',
          'Weekly dispute digest',
          channelDescription: 'Weekly summary of dispute activity',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelWeeklyDigest() async {
    await _plugin.cancel(_weeklyDigestNotificationId);
  }

  /// One-time upgrade guard: previous builds keyed scheduled-notification ids
  /// with `reminder.id.hashCode & 0x7FFFFFFF`, which differs from the current
  /// FNV-1a derivation used by [cancelForReminder] / [cancelForDispute]. On the
  /// first launch after the id change, those orphaned OS alarms can't be
  /// individually cancelled, so before [repairScheduledNotifications] re-arms
  /// the new stable ids we wipe the entire alarm queue exactly once. Guarded
  /// by a SharedPreferences bool so it runs only once per upgrade boundary and
  /// never blocks app start on failure.
  Future<void> migrateNotificationIdsIfNeeded() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final migrated = sp.getBool(_kPrefMigratedFnv1aIds) ?? false;
      if (migrated) return;
      await _plugin.cancelAll();
      await sp.setBool(_kPrefMigratedFnv1aIds, true);
    } catch (e) {
      debugPrint('migrateNotificationIdsIfNeeded failed: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
