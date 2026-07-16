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
import 'package:refund_radar/core/router/app_routes.dart';
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
    // CRITICAL: if hydration throws, we still need to call runApp so the
    // user sees SOMETHING (not a black screen). The zone error handler
    // catches uncaught exceptions but does NOT call runApp — so any throw
    // before runApp = black screen.
    try {
      await hydratePersistedAppState(container);
    } catch (e, st) {
      debugPrint('hydratePersistedAppState failed (non-fatal): $e\n$st');
    }
    // ME-8: notification deep-links can arrive before the widget tree /
    // router exist (cold-launch tap on a UTR notification). Wire the tap
    // handler through a queue that buffers taps until the router is ready.
    final tapRouter = _NotificationTapRouter(container);
    NotificationService.onNotificationTap = tapRouter.handle;
    try {
      await container.read(notificationServiceProvider).init();
    } catch (e, st) {
      debugPrint('NotificationService.init failed (non-fatal): $e\n$st');
    }
    // 5. Configure RevenueCat in the same container so it can write into
    // `isPremiumProvider` (and persist it) on purchase / restore.
    try {
      await container.read(revenueCatServiceProvider).configure();
    } catch (e, st) {
      debugPrint('RevenueCat.configure failed (non-fatal): $e\n$st');
    }
    // 5b. Configure OneSignal. Coexists with FCM (OneSignal is used only
    //     as a segmentation / analytics layer; FCM stays primary for push
    //     delivery per spec §3 + §6.6). Reads OneSignal app id + api key
    //     from `--dart-define` flags injected by the GitHub Actions
    //     release job. In debug builds without dart-define, OneSignal.configure
    //     is a no-op (service.isInitialized stays false).
    try {
      await container.read(oneSignalServiceProvider).configure(
            appId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
            apiKey: const String.fromEnvironment('ONESIGNAL_API_KEY'),
          );
    } catch (e, st) {
      debugPrint('OneSignal.configure failed (non-fatal): $e\n$st');
    }
    // 5c. FCM foreground message handler (Task C6). Foreground pushes
    //     don't reach the Android shade on their own — render them via
    //     [NotificationService.showSimpleNotification]. Failures are
    //     non-fatal: the platform still banners the message in background.
    //     Use the container-managed singleton rather than a bare
    //     NotificationService() so any future per-instance state stays
    //     consistent.
    try {
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
    } catch (e, st) {
      debugPrint('FCM onMessage listener setup failed (non-fatal): $e\n$st');
    }
    runApp(UncontrolledProviderScope(
      container: container,
      child: const RefundRadarApp(),
    ));
    // ME-8: the router is built lazily inside the handler; mark it ready
    // on the first post-frame callback so a queued cold-launch tap drains
    // only after the navigator is attached (otherwise `goRouter.go` is a
    // no-op).
    WidgetsBinding.instance.addPostFrameCallback((_) => tapRouter.markReady());
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
/// ME-8 wrapper: notification deep-links can arrive before the GoRouter's
/// navigator is attached (cold-launch tap on a UTR notification while the
/// Flutter engine is still wiring the tree). A direct `goRouter.go()`
/// there is a no-op. This router buffers taps in `_pending` until
/// [markReady] is called (post first-frame), then drains them. Once ready,
/// taps dispatch immediately. Only `utr_detected://` payloads are routed;
/// everything else is ignored.
class _NotificationTapRouter {
  _NotificationTapRouter(this._container);
  final ProviderContainer _container;
  bool _ready = false;
  final List<String?> _pending = [];

  void handle(String? payload) {
    if (payload == null) return;
    if (!_ready) {
      _pending.add(payload);
      return;
    }
    _dispatch(payload);
  }

  void markReady() {
    _ready = true;
    if (_pending.isEmpty) return;
    final drained = List<String?>.from(_pending);
    _pending.clear();
    for (final p in drained) {
      _dispatch(p);
    }
  }

  // Rewrite `utr_detected://utr=X&amount=Y&sender=Z` → `?utr=X&amount=Y&sender=Z`
  // so Uri.parse can pull the queryParameters. The scheme `utr_detected`
  // has no host in our payloads, so inserting `?` after `://` is safe and
  // lossless for the values we URL-encoded in the first place.
  void _dispatch(String? payload) {
    if (payload == null || !payload.startsWith('utr_detected://')) return;
    final rest = payload.substring('utr_detected://'.length);
    final uri = Uri.parse('utr_detected://?$rest');
    final utr = uri.queryParameters['utr'] ?? '';
    final amount = double.tryParse(uri.queryParameters['amount'] ?? '');
    final senderRaw = uri.queryParameters['sender'];
    if (utr.isEmpty) return;
    final goRouter = _container.read(goRouterProvider);
    final target = AppRoutes.disputesFormWithParams(
      type: 'upi_p2p',
      utr: utr,
      amount: amount?.toStringAsFixed(0),
      sender: senderRaw,
    );
    goRouter.go(target);
  }
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
  Widget build(BuildContext context) {
    // ref.listen in build() is the idiomatic Riverpod pattern — it
    // auto-disposes on unmount and re-attaches safely on rebuild. The
    // old addPostFrameCallback + initState approach could double-fire
    // notifications if the widget was rebuilt by MaterialApp.builder
    // (e.g. on theme/locale change).
    ref.listen<AsyncValue<UtrDetection>>(utrDetectionProvider, (_, next) {
      next.whenData((detection) async {
        try {
          await ref
              .read(notificationServiceProvider)
              .showUtrDetectedNotification(
                utr: detection.utr,
                amount: detection.amount,
                sender: detection.sender,
              );
        } catch (e) {
          debugPrint('UTR detection notification failed: $e');
        }
      });
    });
    return const SizedBox.shrink();
  }
}
