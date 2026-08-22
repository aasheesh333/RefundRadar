import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// WorkManager-based reminder delivery — the production-grade replacement for
/// AlarmManager (`zonedSchedule`) scheduling.
///
/// WHY: AlarmManager exact alarms need `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`
/// (Android 14 revokes the former, Play policy restricts the latter), and OEM
/// battery managers kill them aggressively. WorkManager is the industry
/// standard for deferrable background work:
///   * survives reboots and app updates without a boot receiver of our own,
///   * runs under Doze / battery saver without extra permissions,
///   * retries automatically via backoff if the process dies mid-task.
///
/// ARCHITECTURE (matches how professional reminder apps ship):
///   1. The app registers ONE-OFF tasks with an `initialDelay` = time until
///      the notification should fire. One-off chains keep wall-clock anchors
///      (9 AM daily comp, Sunday 9 AM digest, next-day 10 AM draft nudge)
///      without periodic-drift: each task reschedules its own successor.
///   2. When the OS runs the task (even with the app process dead), the
///      [callbackDispatcher] below spins up a headless Flutter isolate and
///      shows the local notification via flutter_local_notifications `.show()`
///      — display-only, no alarm permission involved.
///
/// Trade-off vs alarms: in deep Doze the OS may defer a task by minutes.
/// That is acceptable for reminders/digests and is exactly what Play-policy-
/// compliant apps do; nothing survives a user-initiated "Force stop" except a
/// relaunch — that is an Android platform guarantee for ALL apps.

/// Task names passed to [Workmanager]. Distinct from the unique names so the
/// handler can branch on what kind of notification to show.
const String kWmDeadlineTask = 'refund_radar.task.deadline';
const String kWmDailyCompTask = 'refund_radar.task.dailyComp';
const String kWmWeeklyDigestTask = 'refund_radar.task.weeklyDigest';
const String kWmDraftNudgeTask = 'refund_radar.task.draftNudge';

/// Unique work names — one pending task per logical reminder. Re-registering
/// the same name replaces the pending task (ExistingWorkPolicy.replace), so
/// re-arming after edits never duplicates notifications.
String wmDeadlineUniqueName(String reminderId) => 'refund_radar.deadline.$reminderId';
const String wmDailyCompUniqueName = 'refund_radar.dailyComp';
const String wmWeeklyDigestUniqueName = 'refund_radar.weeklyDigest';
const String wmDraftNudgeUniqueName = 'refund_radar.draftNudge';

/// FNV-1a → positive 31-bit id. MUST stay in sync with the legacy
/// `NotificationService.scheduledIdFor` so cancel-by-id keeps working across
/// the migration. Duplicated here because the worker isolate must not import
/// the full NotificationService (keeps the headless isolate tiny).
int wmNotificationIdFor(String reminderId) {
  var hash = 0x811c9dc5;
  for (final byte in reminderId.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

final FlutterLocalNotificationsPlugin _workerPlugin =
    FlutterLocalNotificationsPlugin();
bool _workerNotifInitialized = false;

/// Display-only init inside the background isolate: channels are created by
/// `.show()` on first use; timezone data is NOT needed (no scheduling here).
Future<void> _ensureWorkerNotifInit() async {
  if (_workerNotifInitialized) return;
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _workerPlugin.initialize(settings);
  _workerNotifInitialized = true;
}

/// Next occurrence of [hour]:[minute] local time (today if still ahead,
/// otherwise tomorrow). Uses device-local `DateTime` — the worker isolate
/// never needs the timezone database because it schedules plain delays.
DateTime _nextOccurrence(int hour, int minute) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

/// Re-arm the daily-compensation chain for tomorrow 09:00 — but only while
/// the user's toggle (`settings.notif.daily`) is still on. Chaining from
/// inside the task keeps the wall-clock anchor exact-ish without periodic
/// drift, and lets Settings-off cancel the whole chain by killing the one
/// pending task.
Future<void> _chainDailyCompIfEnabled() async {
  final sp = await SharedPreferences.getInstance();
  if (!(sp.getBool('settings.notif.daily') ?? true)) return;
  final delay = _nextOccurrence(9, 0).difference(DateTime.now());
  await Workmanager().registerOneOffTask(
    wmDailyCompUniqueName,
    kWmDailyCompTask,
    initialDelay: delay < Duration.zero ? Duration.zero : delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Same pattern as [_chainDailyCompIfEnabled] for the Sunday-09:00 digest.
Future<void> _chainWeeklyDigestIfEnabled() async {
  final sp = await SharedPreferences.getInstance();
  if (!(sp.getBool('settings.notif.weekly') ?? false)) return;
  var next = _nextOccurrence(9, 0);
  while (next.weekday != DateTime.sunday) {
    next = next.add(const Duration(days: 1));
  }
  final delay = next.difference(DateTime.now());
  await Workmanager().registerOneOffTask(
    wmWeeklyDigestUniqueName,
    kWmWeeklyDigestTask,
    initialDelay: delay < Duration.zero ? Duration.zero : delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Entry point invoked by the OS when a scheduled task comes due. Must be
/// top-level + `@pragma('vm:entry-point')` so it survives tree-shaking.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await _ensureWorkerNotifInit();
      switch (task) {
        case kWmDeadlineTask:
          final id = (inputData?['notifId'] as int?) ?? 0;
          final title = inputData?['title'] as String? ?? 'Dispute deadline';
          final body = inputData?['body'] as String? ??
              'A dispute deadline is approaching. Open RefundRadar.';
          await _workerPlugin.show(
            id,
            title,
            body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'refund_radar_deadlines',
                'Dispute deadlines',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        case kWmDailyCompTask:
          await _workerPlugin.show(
            9001,
            'Daily compensation summary',
            'Tap to see how much penalty has accrued across your disputes',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'daily_comp_channel',
                'Daily compensation summary',
                channelDescription:
                    'Daily summary of penalty compensation accrued',
                importance: Importance.low,
                priority: Priority.low,
              ),
            ),
          );
          await _chainDailyCompIfEnabled();
        case kWmWeeklyDigestTask:
          await _workerPlugin.show(
            9002,
            'Weekly dispute digest',
            'Tap to see your dispute activity this week',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'weekly_digest_channel',
                'Weekly dispute digest',
                channelDescription: 'Weekly summary of dispute activity',
                importance: Importance.low,
                priority: Priority.low,
              ),
            ),
          );
          await _chainWeeklyDigestIfEnabled();
        case kWmDraftNudgeTask:
          await _workerPlugin.show(
            9003,
            'Unfinished dispute?',
            'You have a saved draft waiting. Finish filing to recover your money.',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'draft_nudge_channel',
                'Unfinished draft reminders',
                channelDescription:
                    'Reminder when a saved dispute draft is waiting',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
        default:
          debugPrint('reminder_worker: unknown task "$task" — ignoring');
      }
      return true;
    } catch (e, st) {
      // Returning false asks WorkManager to retry with backoff — a transient
      // failure (process death mid-show) still delivers eventually.
      debugPrint('reminder_worker[$task] failed: $e\n$st');
      return false;
    }
  });
}
