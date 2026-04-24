import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCvbiCYSk7MAaKQX1eZkjBuNV6Nyl9U664',
    appId: '1:812302081374:web:ed023b6696cbf19a74c3cf',
    messagingSenderId: '812302081374',
    projectId: 'expense1-512a2',
    authDomain: 'expense1-512a2.firebaseapp.com',
    storageBucket: 'expense1-512a2.firebasestorage.app',
    measurementId: 'G-ENQWK1MCWT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY', // Native android will rely on google-services.json
    appId: '1:YOUR_ANDROID_APP_ID',
    messagingSenderId: '812302081374',
    projectId: 'expense1-512a2',
    storageBucket: 'expense1-512a2.firebasestorage.app',
  );
}
