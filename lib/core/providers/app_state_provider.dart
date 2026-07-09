import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:refund_radar/services/notification_service.dart';

/// App-level global state: premium-flag + install timestamp + free-dispute counter.
///
/// `isPremiumProvider` is the one place RevenueCat (B3) flips when purchases
/// succeed or restore runs. Free-tier telemetry (the "second dispute"
/// paywall gate and the "free_limit_hit" FCM topic) reads from here.
///
/// We persist `isPremium` to SharedPreferences so the unsynced simple
/// launch state matches the RevenueCat customer info on the first
/// successful fetch — see B3. Until B3 lands, `isPremiumProvider` is
/// always `false` (free user) which keeps all the free-tier gates live.

final _kPrefPremium = 'app.isPremium';
const _kPrefInstallTs = 'app.installTsMs';
const _kPrefNotifDeadline = 'settings.notif.deadline';
const _kPrefNotifDaily = 'settings.notif.daily';
const _kPrefNotifWeekly = 'settings.notif.weekly';

/// `true` when the user has an active premium subscription (RevenueCat).
/// Defaults to `false`. Mutated only through `setPremium`.
final isPremiumProvider = StateProvider<bool>((ref) => false);

/// Notification preference toggles (persisted). Defaults: deadline+daily on.
final notifDeadlineProvider = StateProvider<bool>((ref) => true);
final notifDailyProvider = StateProvider<bool>((ref) => true);
final notifWeeklyProvider = StateProvider<bool>((ref) => false);

Future<void> persistNotifPref(
  dynamic ref, {
  required String key,
  required bool value,
}) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(key, value);
  if (key == _kPrefNotifDeadline) {
    ref.read(notifDeadlineProvider.notifier).state = value;
  } else if (key == _kPrefNotifDaily) {
    ref.read(notifDailyProvider.notifier).state = value;
  } else if (key == _kPrefNotifWeekly) {
    ref.read(notifWeeklyProvider.notifier).state = value;
  }
}

Future<void> setNotifDeadline(dynamic ref, bool value) async {
  if (value) {
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {}
  }
  await persistNotifPref(ref, key: _kPrefNotifDeadline, value: value);
}

Future<void> setNotifDaily(dynamic ref, bool value) =>
    persistNotifPref(ref, key: _kPrefNotifDaily, value: value);

Future<void> setNotifWeekly(dynamic ref, bool value) =>
    persistNotifPref(ref, key: _kPrefNotifWeekly, value: value);

/// Number of hours since the first launch on this device. Returns 0 before
/// the install timestamp has been initialised (first read of the session).
final installedHoursProvider = FutureProvider<int>((ref) async {
  final sp = await SharedPreferences.getInstance();
  final now = DateTime.now().millisecondsSinceEpoch;
  var ts = sp.getInt(_kPrefInstallTs);
  if (ts == null) {
    ts = now;
    await sp.setInt(_kPrefInstallTs, ts);
  }
  final elapsedMs = now - ts;
  return elapsedMs ~/ Duration.millisecondsPerHour;
});

/// Count of disputes created by this free user since install. Resets when
/// premium is purchased. Persisted so it survives app restarts and survives
/// the first load of the dispute list — used by the 2nd-dispute paywall gate
/// (B3) and the top "You hit your free limit" banner.
final freeDisputesUsedProvider =
    StateNotifierProvider<FreeDisputeCounter, int>((ref) => FreeDisputeCounter());

class FreeDisputeCounter extends StateNotifier<int> {
  FreeDisputeCounter() : super(0);

  Future<void> increment() async {
    state = state + 1;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('app.freeDisputesUsed', state);
  }

  Future<void> reset() async {
    state = 0;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('app.freeDisputesUsed', 0);
  }

  Future<void> hydrate() async {
    final sp = await SharedPreferences.getInstance();
    state = sp.getInt('app.freeDisputesUsed') ?? 0;
  }
}

/// Compact helper for the FCM reevaluator (B5). Reads premium + installed-hours
/// in one place so the effect doesn't need to know all the providers.
/// Accepts either Ref or WidgetRef since both expose `read()` / `watch()`.
Future<({bool isPremium, int installedHours})> readFcmInputs(
    dynamic ref) async {
  if (ref is Ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final hours = await ref.watch(installedHoursProvider.future);
    return (isPremium: isPremium, installedHours: hours);
  } else if (ref is WidgetRef) {
    final isPremium = ref.watch(isPremiumProvider);
    final hours = await ref.watch(installedHoursProvider.future);
    return (isPremium: isPremium, installedHours: hours);
  }
  throw ArgumentError('readFcmInputs needs Ref or WidgetRef');
}

/// Load persisted `isPremium` / `freeDisputesUsed` into their providers on
/// boot. Call from `main()` once the ProviderContainer is available — or from
/// a top-level ConsumerWidget `ref.listenSelf` (current approach: gate B3
/// calls this after RevenueCat finishes configuring).
Future<void> hydratePersistedAppState(dynamic ref) async {
  final sp = await SharedPreferences.getInstance();
  ref.read(isPremiumProvider.notifier).state =
      sp.getBool(_kPrefPremium) ?? false;
  ref.read(notifDeadlineProvider.notifier).state =
      sp.getBool(_kPrefNotifDeadline) ?? true;
  ref.read(notifDailyProvider.notifier).state =
      sp.getBool(_kPrefNotifDaily) ?? true;
  ref.read(notifWeeklyProvider.notifier).state =
      sp.getBool(_kPrefNotifWeekly) ?? false;
  await ref.read(freeDisputesUsedProvider.notifier).hydrate();
}

/// Persist premium flag. Called by B3 RevenueCat purchase flow.
Future<void> persistPremium(dynamic ref, bool value) async {
  ref.read(isPremiumProvider.notifier).state = value;
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kPrefPremium, value);
  if (value) {
    await ref.read(freeDisputesUsedProvider.notifier).reset();
  }
}
