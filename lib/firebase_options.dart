// File generated for DolphinCoder LMS / LingoDolphy
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgT9jU1xKQRHnI3XoH637rTu6a62Lt-5g',
    appId: '1:954842353363:android:f55a2da7ef17e5fd328e26',
    messagingSenderId: '954842353363',
    projectId: 'speedup-812dc',
    storageBucket: 'speedup-812dc.firebasestorage.app',
  );
}
