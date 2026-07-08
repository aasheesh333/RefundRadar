import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-EXAMPLE',
    appId: '1:1234567890:android:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'refund-radar',
    storageBucket: 'refund-radar.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD-EXAMPLE',
    appId: '1:1234567890:ios:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'refund-radar',
    storageBucket: 'refund-radar.appspot.com',
    iosBundleId: 'com.refundradar.app',
  );

  static const FirebaseOptions currentPlatform = android;
}
