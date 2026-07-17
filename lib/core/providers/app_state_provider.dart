import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:refund_radar/core/providers/premium_provider.dart';
export 'package:refund_radar/core/providers/premium_provider.dart'
    show isPremiumProvider;
import 'package:refund_radar/core/providers/sms_detection_provider.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
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
const _kPrefOnboarded = 'app.hasSeenOnboarding';

/// `true` once the user has seen the onboarding slides + sms/banks flow
/// and reached home at least once. Persisted so the router can skip
/// onboarding on subsequent launches. Defaults to `false` (fresh install).
final hasSeenOnboardingProvider = StateProvider<bool>((ref) => false);

/// Mark onboarding as seen and persist it. Call from the onboarding end
/// points: the Skip button on the slides, the "Continue" on the add-banks
/// screen, and any early-exit that lands on /home. Accepts an optional
/// [ref] so the in-memory provider is also updated (the router reads it).
Future<void> markOnboardingComplete([dynamic ref]) async {
  if (ref != null) {
    ref.read(hasSeenOnboardingProvider.notifier).state = true;
  }
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kPrefOnboarded, true);
}

/// `true` when the user has an active premium subscription (RevenueCat).
///
/// **Task 8.3** moved this from a plain `StateProvider<bool>` declared
/// here to a derived `Provider<bool>` in [`premium_provider.dart`] that
/// reads from `premiumStatusProvider` (an `AsyncValue<bool>`). All existing
/// `ref.watch(isPremiumProvider)` sites keep working as before — `loading`
/// and `error` collapse to `false` (free), so paywall gates remain
/// fail-safe during RevenueCat's brief startup fetch.
///
/// Re-exported at the top of this file (must come before declarations)
/// for the convenience of files that already
/// `import 'app_state_provider.dart'`.

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
  // Task 8.3 — seed the authoritative AsyncValue<bool> with the persisted
  // premium state (or `false` on first install). This unblocks any UI
  // showing a loading spinner while RevenueCat syncs, and consumer gates
  // collapse loading → false (free) so paywalls stay fail-safe.
  setPremiumStatus(ref, sp.getBool(_kPrefPremium) ?? false);
  ref.read(hasSeenOnboardingProvider.notifier).state =
      sp.getBool(_kPrefOnboarded) ?? false;
  ref.read(notifDeadlineProvider.notifier).state =
      sp.getBool(_kPrefNotifDeadline) ?? true;
  ref.read(notifDailyProvider.notifier).state =
      sp.getBool(_kPrefNotifDaily) ?? true;
  ref.read(notifWeeklyProvider.notifier).state =
      sp.getBool(_kPrefNotifWeekly) ?? false;
  ref.read(smsDetectionEnabledProvider.notifier).state =
      await loadSmsDetectionEnabled();
  await ref.read(freeDisputesUsedProvider.notifier).hydrate();
  // Theme mode + locale are persisted in their own SharedPreferences keys
  // (theme_provider.dart). Hydrate them last so the first frame renders
  // with the user's chosen language + appearance rather than the defaults.
  await hydrateThemeAndLocale(ref);
}

/// Persist premium flag. Called by B3 RevenueCat purchase flow.
Future<void> persistPremium(dynamic ref, bool value) async {
  // Mirror through the authoritative provider (Task 8.3) so premium-aware
  // UI can render loading/data states distinctly. `isPremiumProvider`
  // (the derived bool) follows automatically.
  setPremiumStatus(ref, value);
  final sp = await SharedPreferences.getInstance();
  await sp.setBool(_kPrefPremium, value);
  if (value) {
    await ref.read(freeDisputesUsedProvider.notifier).reset();
  }
}
