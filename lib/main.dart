import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/core/providers/app_state_provider.dart';
import 'package:refund_radar/core/providers/fcm_reevaluater.dart';
import 'package:refund_radar/core/providers/utr_detection_provider.dart';
import 'package:refund_radar/core/router/app_router.dart';
import 'package:refund_radar/core/theme/app_theme.dart';
import 'package:refund_radar/core/providers/theme_provider.dart';
import 'package:refund_radar/data/models/utr_detection.dart';
import 'package:refund_radar/l10n/app_localizations.dart';
import 'package:refund_radar/services/notification_service.dart';
import 'package:refund_radar/services/revenue_cat_service.dart';
import 'package:refund_radar/services/onesignal_service.dart';
import 'package:refund_radar/firebase_options.dart';

/// Crashbus configuration flag. If Firebase fails to initialise (e.g. test/dev
/// without real config), we run without Crashlytics rather than letting the
/// app crash on startup. Set to `true` by `_initFirebase` on success.
bool _crashlyticsEnabled = false;

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _crashlyticsEnabled = true;
  } catch (e, st) {
    // Firebase placeholder config - real values set via GitHub secrets later.
    // Crashlytics not initialised; the error zone below becomes a no-op.
    debugPrint('Firebase init skipped: $e');
    debugPrint(st.toString());
  }

  if (_crashlyticsEnabled) {
    // 1. Catch Flutter framework errors (rendering, async widget errors) and
    //    forward them to Crashlytics in addition to the default console.
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always surface in debug (console + red screen). In release the
      // Crashlytics report is the user-facing signal — presentError is a
      // no-op there so this is safe on both paths.
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // 2. Catch any uncaught errors from the platform (outside the Flutter
    //    framework) — e.g. isolate crashes.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true; // handled — don't re-throw to the platform
    };

    // B8: enable Firestore offline persistence. Cache 50 MB so dispute /
    //     reminder reads + writes survive transient network loss — the
    //     app is info-only so even a multi-day outage keeps the user's
    //     drafts + status queries working. Done inside the
    //     `_crashlyticsEnabled` branch because it only works for real
    //     Firebase projects. Failures here are non-fatal: a re-activated
    //     cache from a previous run is preserved by the SDK automatically.
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 50 * 1024 * 1024, // 50 MB
      );
    } catch (e) {
      debugPrint('Firestore persistence not enabled: $e');
    }
  }
}

void main() {
  // 3. Wrap the entire app in a crash-capturing async zone. Any async error
  //    not handled by Future.catchError goes here first.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _initFirebase();
    // 4. Hydrate persisted app state (premium flag, free-dispute counter).
    //    Done before runApp so the first frame renders with the right
    //    entitlement. RevenueCat's own customer-info updates will overwrite
    //    this once it succeeds.
    final container = ProviderContainer();
    await hydratePersistedAppState(container);
    // 5a. Initialise local notifications (B6 reminders local push). Safe
    //     no-op if permission hasn't been granted yet — user grants via
    //     settings UI or the onboarding SMS screen. Wire the notification
    //     tap callback BEFORE init so the first tap routes correctly too
    //     (Task C7): the static dispatch reads `goRouterProvider` from
    //     the same container.
    NotificationService.onNotificationTap =
        _buildNotificationTapHandler(container);
    await container.read(notificationServiceProvider).init();
    // 5. Configure RevenueCat in the same container so it can write into
    //    `isPremiumProvider` (and persist it) on purchase / restore.
    await container.read(revenueCatServiceProvider).configure();
    // 5b. Configure OneSignal. Coexists with FCM (OneSignal is used only
    //     as a segmentation / analytics layer; FCM stays primary for push
    //     delivery per spec §3 + §6.6). Reads OneSignal app id + api key
    //     from `--dart-define` flags injected by the GitHub Actions
    //     release job. In debug builds without dart-define, OneSignal.configure
    //     is a no-op (service.isInitialized stays false).
    await container.read(oneSignalServiceProvider).configure(
          appId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
          apiKey: const String.fromEnvironment('ONESIGNAL_API_KEY'),
        );
    // 5c. FCM foreground message handler (Task C6). Foreground pushes
    //     don't reach the Android shade on their own — render them via
    //     [NotificationService.showSimpleNotification]. Failures are
    //     non-fatal: the platform still banners the message in background.
    //     Use the container-managed singleton rather than a bare
    //     NotificationService() so any future per-instance state stays
    //     consistent.
    if (_crashlyticsEnabled) {
      final notifService = container.read(notificationServiceProvider);
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        try {
          notifService.showSimpleNotification(
            title: notification.title ?? '',
            body: notification.body ?? '',
          );
        } catch (e) {
          debugPrint('FCM foreground notification show failed: $e');
        }
      });
    }
    runApp(UncontrolledProviderScope(
      container: container,
      child: const RefundRadarApp(),
    ));
  }, (Object error, StackTrace stack) {
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    } else {
      debugPrint('Uncaught async error: $error\n$stack');
    }
  });
}

/// Routes a UTR auto-detect notification tap to the dispute form (Task C7).
///
/// UTR auto-detect notifications carry
/// `utr_detected://utr=...&amount=...&sender=...` (see
/// `NotificationService.showUtrDetectedNotification`). We rewrite the
/// custom scheme into a `?`-style query and extract the three fields.
/// The dispute form reads them as optional constructor params and
/// pre-fills UTR / amount; a missing amount is dropped (the form still
/// opens with the UTR only).
void Function(String? payload) _buildNotificationTapHandler(
  ProviderContainer container,
) {
  return (String? payload) {
    if (payload == null || !payload.startsWith('utr_detected://')) return;
    // Rewrite `utr_detected://utr=X&amount=Y&sender=Z` → `?utr=X&amount=Y&sender=Z`
    // so Uri.parse can pull the queryParameters. The scheme `utr_detected`
    // has no host in our payloads, so inserting `?` after `://` is safe and
    // lossless for the values we URL-encoded in the first place.
    final rest = payload.substring('utr_detected://'.length);
    final uri = Uri.parse('utr_detected://?$rest');
    final utr = uri.queryParameters['utr'] ?? '';
    final amount = double.tryParse(uri.queryParameters['amount'] ?? '');
    final senderRaw = uri.queryParameters['sender'];
    if (utr.isEmpty) return;
    final qp = <String, String>{
      'type': 'upi_p2p',
      'utr': utr,
      if (amount != null) 'amount': amount.toStringAsFixed(0),
      if (senderRaw != null && senderRaw.isNotEmpty) 'sender': senderRaw,
    };
    final goRouter = container.read(goRouterProvider);
    final target = Uri(path: '/disputes/form', queryParameters: qp).toString();
    goRouter.go(target);
  };
}

class RefundRadarApp extends ConsumerWidget {
  const RefundRadarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Refund Radar',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Stack(
      children: [
        child ?? const SizedBox.shrink(),
        // FCM topic re-evaluation effect (B5). Runs for the whole session.
        const FcmReevaluator(),
        // Task C6: watch the UTR auto-detect stream and fire an instant
        // notification for each new detection. Renders nothing.
        const UtrDetectionListener(),
      ],
    ),
    );
  }
}

/// Task C6 listener that watches [utrDetectionProvider] and fires a local
/// notification for every new auto-detected UTR. Renders nothing visible —
/// it exists purely to keep a [ref.listen] subscription alive for the
/// whole session (Riverpod re-attaches on dispose/rebuild safely).
///
/// Notifications are best-effort: a permission gap or a plugin error must
/// not crash the app — we swallow and debug-print. The state list that
/// backs the home "Detected transactions" banner is updated inside
/// [utrDetectionsProvider]'s notifier, independent of this widget.
class UtrDetectionListener extends ConsumerStatefulWidget {
  const UtrDetectionListener({super.key});

  @override
  ConsumerState<UtrDetectionListener> createState() =>
      _UtrDetectionListenerState();
}

class _UtrDetectionListenerState extends ConsumerState<UtrDetectionListener> {
  @override
  void initState() {
    super.initState();
    // Subscribe once on mount; ref.listen auto-disposes on dispose.
    // We use addPostFrameCallback so ref is ready and so the listener
    // can safely reach the notification service.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listen<AsyncValue<UtrDetection>>(
        utrDetectionProvider,
        (_, next) {
          next.whenData((detection) async {
            try {
              await ref.read(notificationServiceProvider)
                  .showUtrDetectedNotification(
                utr: detection.utr,
                amount: detection.amount,
                sender: detection.sender,
              );
            } catch (e) {
              debugPrint('UTR detection notification failed: $e');
            }
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
