// File generated for Paralegal Quest — Firebase multi-platform configuration.
// Provides DefaultFirebaseOptions.currentPlatform so Firebase.initializeApp()
// works correctly on both Web and Android without extra config files.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD9mAIowzH2_BVcaHCxZGXR0jkARl0uJFI',
    appId: '1:74723133762:web:9dbc45d99c65baa23be0db',
    messagingSenderId: '74723133762',
    projectId: 'paralegal-quest-game',
    authDomain: 'paralegal-quest-game.firebaseapp.com',
    storageBucket: 'paralegal-quest-game.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDtxiMqb5zu_cT_Lmgb84mOLUeku7uk8TI',
    appId: '1:74723133762:android:cb3a410ed10607f93be0db',
    messagingSenderId: '74723133762',
    projectId: 'paralegal-quest-game',
    storageBucket: 'paralegal-quest-game.firebasestorage.app',
  );
}
