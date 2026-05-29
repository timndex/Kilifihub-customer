// ============================================================
// Firebase Configuration Options
// ============================================================
//
// IMPORTANT: This file contains PLACEHOLDER values.
// Replace them with real values by running:
//
//   flutterfire configure
//
// This command will generate the correct firebase_options.dart
// based on your Firebase project settings.
//
// For now, these placeholders allow the app to compile.
// Firebase features (messaging, analytics, etc.) will NOT
// work until you replace these with real configuration values.
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder Firebase options.
///
/// Run `flutterfire configure` to generate the real file,
/// then replace this entire file with the generated output.
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
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // -------------------------------------------------------
  // Android Firebase Configuration
  // Replace these values with your actual Firebase project values
  // -------------------------------------------------------
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_ANDROID_API_KEY',
    appId: '1:REPLACE_WITH_YOUR_PROJECT_NUMBER:android:REPLACE_WITH_YOUR_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
  );

  // -------------------------------------------------------
  // iOS Firebase Configuration
  // Replace these values with your actual Firebase project values
  // -------------------------------------------------------
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
    appId: '1:REPLACE_WITH_YOUR_PROJECT_NUMBER:ios:REPLACE_WITH_YOUR_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
    iosClientId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER-ios-REPLACE_WITH_YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.kilifihub.customer',
  );

  // -------------------------------------------------------
  // Web Firebase Configuration
  // Replace these values with your actual Firebase project values
  // -------------------------------------------------------
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_WEB_API_KEY',
    appId: '1:REPLACE_WITH_YOUR_PROJECT_NUMBER:web:REPLACE_WITH_YOUR_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
    authDomain: 'REPLACE_WITH_YOUR_PROJECT_ID.firebaseapp.com',
    measurementId: 'G-REPLACE_WITH_YOUR_MEASUREMENT_ID',
  );

  // -------------------------------------------------------
  // macOS Firebase Configuration
  // Replace these values with your actual Firebase project values
  // -------------------------------------------------------
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_IOS_API_KEY',
    appId: '1:REPLACE_WITH_YOUR_PROJECT_NUMBER:ios:REPLACE_WITH_YOUR_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
    iosClientId: 'REPLACE_WITH_YOUR_PROJECT_NUMBER-ios-REPLACE_WITH_YOUR_MACOS_CLIENT_ID',
    iosBundleId: 'com.kilifihub.customer',
  );
}
