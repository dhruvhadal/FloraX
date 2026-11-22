// File generated for FloraX Firebase Configuration (Spark Plan Production)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with FloraX Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5K7xkGn2gJM7P5Wtv4fpQULUTu8CWZsc',
    appId: '1:480833420396:android:301b4982f41f64ac4eac49',
    messagingSenderId: '480833420396',
    projectId: 'florax-leafguard',
    storageBucket: 'florax-leafguard.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC5K7xkGn2gJM7P5Wtv4fpQULUTu8CWZsc',
    appId: '1:480833420396:ios:301b4982f41f64ac4eac49',
    messagingSenderId: '480833420396',
    projectId: 'florax-leafguard',
    storageBucket: 'florax-leafguard.firebasestorage.app',
    iosBundleId: 'com.florax.crophealth',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5K7xkGn2gJM7P5Wtv4fpQULUTu8CWZsc',
    appId: '1:480833420396:web:301b4982f41f64ac4eac49',
    messagingSenderId: '480833420396',
    projectId: 'florax-leafguard',
    storageBucket: 'florax-leafguard.firebasestorage.app',
  );
}
