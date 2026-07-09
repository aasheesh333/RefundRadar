import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Production Firebase config for Refund Radar.
///
/// **Build-time injection (no google-services.json committed):**
/// We deliberately do NOT commit `google-services.json` to the repo and do
/// NOT base64-encode it as a GitHub secret either. Instead, the five values
/// below are injected at build time via `--dart-define` flags sourced from
/// individual GitHub secrets (see `.github/workflows/android.yml` → release
/// job). This keeps the Firebase config out of the repo and avoids the
/// single-blob secret pattern.
///
/// **Debug / dev fallback:**
/// If no `--dart-define` flags are passed (e.g. local dev, debug job on CI),
/// the placeholder values below take over so the app still boots. Firebase
/// calls (Crashlytics, Analytics, FCM, Remote Config, Firestore) silently
/// no-op via the resilience wrappers in `main.dart`, `AnalyticsService`,
/// and `FcmTopicService`.
///
/// **Compile-time override (any build):**
/// Pass `--dart-define=FB_ANDROID_API_KEY=...` (and the four siblings)
/// through `flutter build`; the dart-define values take precedence over the
/// placeholder constants.
class DefaultFirebaseOptions {
  static FirebaseOptions get android {
    final apiKey = const String.fromEnvironment(
      'FB_ANDROID_API_KEY',
      defaultValue: _placeholderApiKey,
    );
    final appId = const String.fromEnvironment(
      'FB_ANDROID_APP_ID',
      defaultValue: _placeholderAppId,
    );
    final messagingSenderId = const String.fromEnvironment(
      'FB_MESSAGING_SENDER_ID',
      defaultValue: _placeholderSenderId,
    );
    final projectId = const String.fromEnvironment(
      'FB_PROJECT_ID',
      defaultValue: 'refund-radar-9eb75',
    );
    final storageBucket = const String.fromEnvironment(
      'FB_STORAGE_BUCKET',
      defaultValue: 'refund-radar-9eb75.firebasestorage.app',
    );
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  static FirebaseOptions get ios {
    final apiKey = const String.fromEnvironment(
      'FB_IOS_API_KEY',
      defaultValue: _placeholderApiKey,
    );
    final appId = const String.fromEnvironment(
      'FB_IOS_APP_ID',
      defaultValue: _placeholderIosAppId,
    );
    final messagingSenderId = const String.fromEnvironment(
      'FB_MESSAGING_SENDER_ID',
      defaultValue: _placeholderSenderId,
    );
    final projectId = const String.fromEnvironment(
      'FB_PROJECT_ID',
      defaultValue: 'refund-radar-9eb75',
    );
    final storageBucket = const String.fromEnvironment(
      'FB_STORAGE_BUCKET',
      defaultValue: 'refund-radar-9eb75.firebasestorage.app',
    );
    final iosBundleId = const String.fromEnvironment(
      'FB_IOS_BUNDLE_ID',
      defaultValue: 'com.dhanuk.refundradar',
    );
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
    );
  }

  /// Always android for now (Android-only build pipeline). When iOS lands,
  /// switch on defaultTargetPlatform.
  static FirebaseOptions get currentPlatform => android;

  // ---------- placeholder values (used in dev until secrets land) ----------
  static const _placeholderApiKey = 'AIzaSyD-EXAMPLE';
  static const _placeholderAppId = '1:1234567890:android:abcdef123456';
  static const _placeholderIosAppId = '1:1234567890:ios:abcdef123456';
  static const _placeholderSenderId = '1234567890';
}
