import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'reminder_worker.dart';

const _kPrefMigratedFnv1aIds = 'migrated_fnv1a_ids';

/// One-time migration: pre-WorkManager builds scheduled alarms via
/// `zonedSchedule` (AlarmManager). Those pending OS alarms can't be
/// individually cancelled by unique name, so on the first launch after the
/// WorkManager switch we wipe the entire FLN alarm queue exactly once.
/// [repairScheduledNotifications] then re-arms everything as WorkManager
/// tasks on this same cold start. Guarded by a SharedPreferences bool.
const _kPrefMigratedToWorkManager = 'migrated_workmanager_v1';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Optional callback invoked when the user taps a local notification.
  /// The argument is the platform-supplied `payload` string (see
  /// [showUtrDetectedNotification]). Wired up in `main.dart` using the
  /// `goRouterProvider` so taps can route into the app. Kept as a static
  /// because the platform channel calls back outside the Riverpod build
  /// lifecycle — but the callback itself uses the container to resolve
  /// the router.
  static void Function(String? payload)? onNotificationTap;

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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final cb = onNotificationTap;
        if (cb == null) return;
        // Allow the callback to record a redirect path; the actual
        // `router.go(...)` happens inside the callback (which holds a ref
        // to the go router).
        cb(response.payload);
      },
    );
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Stable positive id for a reminder — shared with the worker isolate via
  /// [wmNotificationIdFor] so ids match across process boundaries. Kept as a
  /// delegating static because legacy call sites reference it directly.
  static int scheduledIdFor(String reminderId) =>
      wmNotificationIdFor(reminderId);

  static int cancelIdFor(String reminderId) {
    return scheduledIdFor(reminderId);
  }

  /// Schedule a dispute-deadline reminder for when the app may be fully
  /// closed.
  ///
  /// Android: registers a WorkManager one-off task with `initialDelay`
  /// = time until [fireAt]. The OS persists the task across reboots and runs
  /// it under Doze without any exact-alarm permission; the worker isolate
  /// shows the notification (see reminder_worker.dart). Re-registering the
  /// same reminder replaces its pending task instead of duplicating.
  ///
  /// iOS keeps the AlarmManager-style `zonedSchedule` path: iOS local
  /// notifications are already reliable and BGTaskScheduler is too throttled
  /// to guarantee delivery windows.
  Future<int> scheduleDeadlineReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    final id = scheduledIdFor(reminderId);
    if (!Platform.isIOS) {
      var delay = fireAt.difference(DateTime.now());
      if (delay < Duration.zero) delay = Duration.zero;
      await Workmanager().registerOneOffTask(
        wmDeadlineUniqueName(reminderId),
        kWmDeadlineTask,
        inputData: {'notifId': id, 'title': title, 'body': body},
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return id;
    }
    const androidDetails = AndroidNotificationDetails(
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

  /// Cancel a deadline reminder's WorkManager task (Android) plus any legacy
  /// pending FLN alarm with the same numeric id (pre-migration installs).
  Future<void> cancelForReminder(String reminderId) async {
    try {
      await Workmanager().cancelByUniqueName(wmDeadlineUniqueName(reminderId));
    } catch (e) {
      debugPrint('cancelByUniqueName($reminderId) failed: $e');
    }
    final id = cancelIdFor(reminderId);
    await _plugin.cancel(id);
  }

  Future<void> cancelForDispute(List<String> reminderIds) async {
    for (final reminderId in reminderIds) {
      await cancelForReminder(reminderId);
    }
  }

  Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
    } catch (e) {
      debugPrint('Workmanager.cancelAll failed: $e');
    }
    await _plugin.cancelAll();
  }

  static const _dailyCompNotificationId = 9001;

  /// Daily compensation digest at ~09:00 local. Implemented as a self-chaining
  /// WorkManager one-off (the worker reschedules tomorrow's task after firing)
  /// so the wall-clock anchor survives without periodic-drift, while still
  /// working when the app process is dead.
  Future<void> scheduleDailyComp() async {
    if (!Platform.isIOS) {
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, 9, 0);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      await Workmanager().registerOneOffTask(
        wmDailyCompUniqueName,
        kWmDailyCompTask,
        initialDelay: next.difference(now),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return;
    }
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
    if (!Platform.isIOS) {
      await Workmanager().cancelByUniqueName(wmDailyCompUniqueName);
      return;
    }
    await _plugin.cancel(_dailyCompNotificationId);
  }

  static const _weeklyDigestNotificationId = 9002;

  /// Weekly dispute digest, Sunday ~09:00 local. Same self-chaining one-off
  /// pattern as [scheduleDailyComp].
  Future<void> scheduleWeeklyDigest() async {
    if (!Platform.isIOS) {
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, 9, 0);
      while (next.weekday != DateTime.sunday || !next.isAfter(now)) {
        next = next.add(const Duration(hours: 1));
      }
      await Workmanager().registerOneOffTask(
        wmWeeklyDigestUniqueName,
        kWmWeeklyDigestTask,
        initialDelay: next.difference(now),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return;
    }
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
    if (!Platform.isIOS) {
      await Workmanager().cancelByUniqueName(wmWeeklyDigestUniqueName);
      return;
    }
    await _plugin.cancel(_weeklyDigestNotificationId);
  }

  /// Draft nudge: ONE-shot closed-app reminder ~next day 10:00 local when
  /// saved dispute drafts exist. Wired once in `main.dart`
  /// (`_bootBackgroundServices`) at cold start — opening/resuming/submitting
  /// a draft changes `DraftRepository.count()`, so the next cold start
  /// naturally re-arms or cancels; no per-edit scheduling. Delivered via
  /// WorkManager on Android (works with the app process dead); no chaining
  /// — every cold start re-derives from draft count.
  ///
  /// Fixed id follows the 9001/9002 app-level-notification pattern:
  /// distinct from the FNV-1a reminder-id space and the negative
  /// instant-show id space, so it can't collide with deadline alarms.
  static const _draftNudgeNotificationId = 9003;

  Future<void> scheduleDraftNudge() async {
    if (!Platform.isIOS) {
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, 10, 0)
          .add(const Duration(days: 1));
      final delay = next.difference(now);
      await Workmanager().registerOneOffTask(
        wmDraftNudgeUniqueName,
        kWmDraftNudgeTask,
        initialDelay: delay < Duration.zero ? Duration.zero : delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10, 0)
            .add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      _draftNudgeNotificationId,
      'Unfinished dispute?',
      'You have a saved draft waiting. Finish filing to recover your money.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'draft_nudge_channel',
          'Unfinished draft reminders',
          channelDescription: 'Reminder when a saved dispute draft is waiting',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelDraftNudge() async {
    if (!Platform.isIOS) {
      await Workmanager().cancelByUniqueName(wmDraftNudgeUniqueName);
      return;
    }
    await _plugin.cancel(_draftNudgeNotificationId);
  }

  /// Task C5: fire an instant high-priority notification the moment a UTR
  /// is auto-detected from an incoming SMS. Tapping the notification opens
  /// the dispute form with the UTR / amount / sender pre-filled — the
  /// routing side parses the payload in the notification-tap handler in
  /// `main.dart`.
  ///
  /// Notification id is the NEGATIVE of `utr.hashCode.abs()` so each UTR
  /// falls in a stable bucket in the negative id space — guaranteed
  /// disjoint from all positive scheduled ids (FNV-1a-derived reminder
  /// ids + daily/weekly 9001/9002), so an instant UTR `show` can never
  /// overwrite a pending scheduled reminder alarm. A re-detection of the
  /// same UTR replaces the previous banner rather than stacking them.
  Future<void> showUtrDetectedNotification({
    required String utr,
    required double? amount,
    required String sender,
  }) async {
    final id = -(utr.hashCode.abs() + 1);
    final title = amount != null
        ? 'Transaction detected — ₹${amount.toInt()}'
        : 'Bank transaction detected';
    final body = 'UTR: $utr from $sender. Start a dispute?';

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'utr_detection_channel',
          'Transaction detection',
          channelDescription:
              'Instant alerts when UTRs are detected in incoming SMS',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // Deep-link payload: `utr_detected://utr=...&amount=...&sender=...`
      // Tap-side handling rewrites this to a parseable URI and routes to
      // the dispute form pre-filled.
      payload: 'utr_detected://utr=$utr'
          '&amount=${amount ?? ''}'
          '&sender=${Uri.encodeComponent(sender)}',
    );
  }

  /// Task C6: foreground FCM push → local notification passthrough.
  ///
  /// FCM foreground messages aren't shown by the platform notification
  /// shade on Android when the app is in the foreground — we render a
  /// basic high-priority local notification so the user still sees the
  /// message. The payload is null here (the FCM message is not a
  /// deep-link trigger like a UTR auto-detect is).
  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    // Negative id space (disjoint from positive scheduled reminder/daily/
    // weekly ids) so a foreground push can never overwrite a pending
    // scheduled alarm.
    final id = -(DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF) + 1);
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fcm_foreground_channel',
          'Push notifications',
          channelDescription: 'Foreground push notifications from RefundRadar',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// One-time upgrade guards, run once per boundary:
  ///
  /// 1. [_kPrefMigratedFnv1aIds] — previous builds keyed scheduled ids with
  ///    `reminder.id.hashCode & 0x7FFFFFFF`, which differs from the current
  ///    FNV-1a derivation. Orphaned OS alarms can't be individually
  ///    cancelled → wipe the alarm queue once before re-arm.
  /// 2. [_kPrefMigratedToWorkManager] — the switch from AlarmManager
  ///    (`zonedSchedule`) to WorkManager tasks. Pending legacy alarms are
  ///    wiped once; [repairScheduledNotifications] re-arms them as
  ///    WorkManager tasks on this same cold start, so nothing is lost.
  Future<void> migrateNotificationIdsIfNeeded() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final migratedFnv = sp.getBool(_kPrefMigratedFnv1aIds) ?? false;
      final migratedWm = sp.getBool(_kPrefMigratedToWorkManager) ?? false;
      if (migratedFnv && migratedWm) return;
      await _plugin.cancelAll();
      if (!migratedWm && !Platform.isIOS) {
        // Legacy AlarmManager tasks live outside WorkManager's namespace —
        // cancelAll() on WorkManager only clears WM work, so also drop any
        // stale WM entries from interrupted upgrades.
        try {
          await Workmanager().cancelAll();
        } catch (_) {}
      }
      await sp.setBool(_kPrefMigratedFnv1aIds, true);
      await sp.setBool(_kPrefMigratedToWorkManager, true);
    } catch (e) {
      debugPrint('migrateNotificationIdsIfNeeded failed: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
