import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:cloud_firestore/cloud_firestore.dart'; // Importirajte FirebaseFirestore

// Funkcija za praćenje novih dokumenata
Future<int> getNewDocumentsCount(String locationName) async {
  if (locationName.isEmpty) {
    throw ArgumentError('Location name cannot be empty');
  }

  final querySnapshot = await FirebaseFirestore.instance
      .collection('locations/$locationName/documents')
      .where('date',
          isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 1))))
      .get();

  return querySnapshot.size;
}

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
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBd5eqDV9tjtmEFDY7ZHwdiWxQ8_kRVzTY',
    authDomain: 'conexaproject-9660d.firebaseapp.com',
    projectId: 'conexaproject-9660d',
    storageBucket: 'conexaproject-9660d.appspot.com',
    messagingSenderId: '547124767142',
    appId: '1:547124767142:web:927a1889e71a564500c767',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBd5eqDV9tjtmEFDY7ZHwdiWxQ8_kRVzTY',
    authDomain: 'conexaproject-9660d.firebaseapp.com',
    projectId: 'conexaproject-9660d',
    storageBucket: 'conexaproject-9660d.appspot.com',
    messagingSenderId: '547124767142',
    appId: '1:547124767142:android:927a1889e71a564500c767',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBd5eqDV9tjtmEFDY7ZHwdiWxQ8_kRVzTY',
    authDomain: 'conexaproject-9660d.firebaseapp.com',
    projectId: 'conexaproject-9660d',
    storageBucket: 'conexaproject-9660d.appspot.com',
    messagingSenderId: '547124767142',
    appId: '1:547124767142:ios:927a1889e71a564500c767',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBd5eqDV9tjtmEFDY7ZHwdiWxQ8_kRVzTY',
    authDomain: 'conexaproject-9660d.firebaseapp.com',
    projectId: 'conexaproject-9660d',
    storageBucket: 'conexaproject-9660d.appspot.com',
    messagingSenderId: '547124767142',
    appId: '1:547124767142:macos:927a1889e71a564500c767',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );
}
