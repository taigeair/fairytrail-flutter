// File generated for Fairytrail Firebase project (fairytrail-spring-expo).
// Package/bundle must be app.fairytrail.release to match google-services.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Fairytrail push.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDIrUbUZXh6GLwc_YfkiUGS231DvuH1sxw',
    appId: '1:110709093540:android:bd503401efea849ddf6231',
    messagingSenderId: '110709093540',
    projectId: 'fairytrail-spring-expo',
    storageBucket: 'fairytrail-spring-expo.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAXTAH1lipyNTWyC8OgGWoYjqBNJbIVBf8',
    appId: '1:110709093540:ios:a6477607e9613776df6231',
    messagingSenderId: '110709093540',
    projectId: 'fairytrail-spring-expo',
    storageBucket: 'fairytrail-spring-expo.firebasestorage.app',
    iosClientId:
        '110709093540-fan6ml4hb3n2r9v7a3rq58hbe910q36k.apps.googleusercontent.com',
    iosBundleId: 'app.fairytrail.release',
  );
}
