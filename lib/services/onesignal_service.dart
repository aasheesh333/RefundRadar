import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Refund Radar's OneSignal integration.
///
/// ROLE: a SECONDARY analytics/segmentation channel that mirrors the
/// same 9-state dimensions that the FCM topic subscriber in
/// `lib/services/fcm_topics.dart` writes. FCM remains the primary push
/// transport per spec §3 + §6.6; OneSignal here is configured so that:
///
///   • It does NOT auto-prompt for notification permission (spec §6.6:
///     "ask notification permission contextually after first dispute is
///     created, with a value explainer — never on first launch").
///   • It does NOT take over the FCM token (we leave
///     `firebase_messaging` as the FCM token owner). OneSignal will
///     still receive a OneSignal-subscription ID it uses for its own
///     segmentation; both SDKs can coexist on Android because each
///     maintains its own subscription state.
///   • It syncs the 9 segmentation tags (`dormant_no_dispute`,
///     `active_dispute`, `deadline_missed`, `free_limit_hit`,
///     `premium`, `fastag_user`, `upi_user`, `lang_hi`, `lang_en`)
///     as OneSignal user-tags so that the OneSignal dashboard can be
///     used as a richer campaign composer alongside FCM topic-based
///     Firebase Notification composer.
///
/// All operations are best-effort and silently no-op if OneSignal is
/// unavailable or if the SDK key is not provisioned (debug builds, dev).
class OneSignalService {
  static const _logTag = 'OneSignalService';

  /// Mirrors the FCM topic taxonomy in `lib/services/fcm_topics.dart`.
  /// Converts each topic-key to (String 'true' / 'false') for OneSignal
  /// user-tags — OneSignal tags only accept String values.
  static const topicTagKeys = <String>[
    'dormant_no_dispute',
    'active_dispute',
    'deadline_missed',
    'free_limit_hit',
    'premium',
    'fastag_user',
    'upi_user',
    'lang_hi',
    'lang_en',
  ];

  bool _initialized = false;

  /// Toggle this to true to see OneSignal logs in debug builds only.
  static final bool _debugLog = false;

  static void _log(String msg) {
    if (_debugLog || kDebugMode) debugPrint('[$_logTag] $msg');
  }

  /// Configures OneSignal with the provided app id. The API key is NOT
  /// required on the client (it is only used server-side; we surface it
  /// here only as a sanity check so CI / release builds can verify the
  /// secret is present via dart-define).
  Future<void> configure({
    required String appId,
    String? apiKey,
  }) async {
    if (_initialized) return;
    if (appId.isEmpty) {
      _log('appId empty — OneSignal not initialised (debug mode).');
      return;
    }
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.none);
      await OneSignal.initialize(appId);
      // Spec §6.6: never prompt on first launch. We explicitly opt-out of
      // the auto-prompt here. FCM remains the primary push transport.
      // `consentRequired(true)` makes any OneSignal push-UI require
      // explicit user consent, which we won't request at startup.
      await OneSignal.consentRequired(true);
      _initialized = true;
      _log('configured with appId=$appId apiKeyProvided=${apiKey?.isNotEmpty == true}.');
    } catch (e, st) {
      _log('init failed: $e\n$st');
    }
  }

  /// Pushes the 9 spec-topics as OneSignal user-tags ('true'/'false').
  /// Best-effort; silently no-op on failure. Optional [freeLimitActive]
  /// overrides the historical predicate `!isPremium` (which subscribed
  /// every free user — including just-installed signups — to the
  /// `free_limit_hit` campaign segment). When omitted, defaults to
  /// `!isPremium` to preserve the original behaviour for old callers.
  Future<void> syncTags({
    required int installedHours,
    required int activeDisputes,
    required bool hasExpiredDispute,
    required bool isPremium,
    required bool hasFastag,
    required bool hasUpi,
    required String languageCode,
    bool? freeLimitActive,
  }) async {
    if (!_initialized) return;
    final freeGateOn = freeLimitActive ?? (!isPremium);
    final tagValues = <String, String>{
      'dormant_no_dispute':
          (installedHours >= 48 && activeDisputes == 0) ? 'true' : 'false',
      'active_dispute': activeDisputes >= 1 ? 'true' : 'false',
      'deadline_missed': hasExpiredDispute ? 'true' : 'false',
      'free_limit_hit': freeGateOn ? 'true' : 'false',
      'premium': isPremium ? 'true' : 'false',
      'fastag_user': hasFastag ? 'true' : 'false',
      'upi_user': hasUpi ? 'true' : 'false',
      'lang_hi': languageCode == 'hi' ? 'true' : 'false',
      'lang_en': languageCode == 'en' ? 'true' : 'false',
    };
    try {
      await OneSignal.User.addTags(tagValues);
      _log('synced ${tagValues.length} tags.');
    } catch (e, st) {
      _log('syncTags failed: $e\n$st');
      // Previously silently swallowed — now record a Crashlytics breadcrumb
      // so release builds surface persistent tag-sync failures (otherwise
      // OneSignal segmentation drifts silently from FCM topic state).
      try {
        await FirebaseCrashlytics.instance
            .recordError(e, st, reason: 'OneSignal.syncTags', fatal: false);
      } catch (_) {/* Crashlytics not initialised */}
    }
  }

  /// Surface the current OneSignal subscription id (debug only); useful
  /// for QA to verify end-to-end connectivity. Returns null if not
  /// available.
  String? get subscriptionId {
    if (!_initialized) return null;
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for the singleton [OneSignalService].
final oneSignalServiceProvider = Provider<OneSignalService>((ref) {
  return OneSignalService();
});
