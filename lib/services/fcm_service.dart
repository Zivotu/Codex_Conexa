// lib/services/fcm_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart';

final Logger _logger = Logger();

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final UserService _userService = UserService();

  // Singleton pattern
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Metoda za inicijalizaciju permisija i postavljanje slušatelja tokena
  Future<void> init() async {
    // Traženje dozvola za notifikacije
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _logger.i('Dozvole za notifikacije odobrene.');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      _logger.i('Provisional dozvole za notifikacije odobrene.');
    } else {
      _logger.w('Dozvole za notifikacije nisu odobrene.');
    }

    // Slušanje promjena tokena
    _messaging.onTokenRefresh.listen((newToken) async {
      _logger.i("FCM Token osvježen: $newToken");
      await _updateFcmTokenForCurrentUser(newToken);
    }).onError((err) {
      _logger.e("Greška pri osvježavanju FCM tokena: $err");
    });

    // Slušanje dolaznih poruka (dok je app u fokusu)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.d("Primljena poruka u fokusu: ${message.messageId}");
      // Ovdje možete implementirati logiku za prikazivanje lokalnih notifikacija
    });

    // Slušanje kada se poruka otvori iz pozadine
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.d("Poruka otvorena iz pozadine: ${message.messageId}");
      // Ovdje možete implementirati navigaciju na određeni ekran
    });
  }

  /// Metoda koja se poziva kad se korisnik prijavi ili registrira.
  /// Pokušava dohvatiti trenutni FCM token i ažurirati ga u bazi.
  Future<void> handleUserLogin(User user) async {
    try {
      String? token = await _getTokenWithRetry();
      if (token != null) {
        _logger.i("FCM Token dohvaćen nakon prijave: $token");
        await _updateFcmToken(user.uid, token);
      } else {
        _logger
            .w("Nije uspjelo dohvaćanje FCM tokena nakon prijave korisnika.");
      }
    } catch (e) {
      _logger.e("Greška pri ažuriranju FCM tokena za korisnika: $e");
    }
  }

  /// Pomoćna metoda za dohvaćanje FCM tokena s pokušajem ponovne preuzimanja
  /// u slučaju da dohvat prvi put ne uspije.
  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        String? token = await _messaging.getToken();
        return token;
      } catch (e) {
        _logger.w("Pokušaj $attempt dohvaćanja FCM tokena nije uspio: $e");
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// Ažuriranje tokena za trenutno prijavljenog korisnika, koristeći newToken.
  Future<void> _updateFcmTokenForCurrentUser(String newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _updateFcmToken(user.uid, newToken);
      _logger.i("FCM Token ažuriran za korisnika: ${user.uid}");
    } else {
      _logger.w("Nema prijavljenog korisnika za ažuriranje FCM tokena.");
    }
  }

  /// Ažurira FCM token u Firestoreu
  Future<void> _updateFcmToken(String userId, String token) async {
    try {
      await _userService.updateFcmToken(userId, token);
      _logger.i("FCM Token uspješno ažuriran za korisnika: $userId");
    } catch (e) {
      _logger.e("Neuspješno ažuriranje FCM tokena za korisnika $userId: $e");
    }
  }

  /// Dohvaćanje ili generiranje device ID-a radi sljedivosti uređaja (opcionalno)
  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    return deviceId;
  }
}
