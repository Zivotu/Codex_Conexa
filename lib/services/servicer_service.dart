// lib/services/servicer_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

class ServicerService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Logger _logger = Logger();

  /// Kreira servicer dokument u root kolekciji 'servicers'
  Future<void> createServicerDocument({
    required User user,
    required Map<String, dynamic> servicerData,
  }) async {
    try {
      final servicerDocRef = _db.collection('servicers').doc(user.uid);

      final servicerDataWithUserType = {
        'servicerId': user.uid,
        'userId': user.uid,
        'userType': 'servicer',
        'email': user.email ?? '',
        'displayName': servicerData['displayName'] ?? '',
        'lastName': servicerData['lastName'] ?? '',
        'username': servicerData['username'] ?? '',
        'phone': servicerData['phone'] ?? '',
        'address': servicerData['address'] ?? '',
        'profileImageUrl': servicerData['profileImageUrl'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        // Dodajte dodatna polja servisera ovdje
        'companyName': servicerData['companyName'] ?? '',
        'companyAddress': servicerData['companyAddress'] ?? '',
        'companyEmail': servicerData['companyEmail'] ?? '',
        'companyPhone': servicerData['companyPhone'] ?? '',
        'fcmToken': servicerData['fcmToken'] ?? '',
        'selectedCategories': servicerData['selectedCategories'] ?? [],
        'website': servicerData['website'] ?? '',
        'workshopPhotoUrl': servicerData['workshopPhotoUrl'] ?? '',
        'workingCountry': servicerData['workingCountry'] ?? '',
        'workingCity': servicerData['workingCity'] ?? '',
        // Ostala polja po potrebi
      };

      await servicerDocRef.set(servicerDataWithUserType);
      _logger.d("Servicer document created: $servicerDataWithUserType");
    } catch (e) {
      _logger.e("Error creating servicer document: $e");
    }
  }

  /// Ažurira FCM token za trenutnog servisera u root kolekciji 'servicers'
  Future<void> updateServicerToken() async {
    try {
      String? token = await _messaging.getToken();
      String servicerId = _auth.currentUser!.uid;
      final servicerDocRef = _db.collection('servicers').doc(servicerId);

      await servicerDocRef.update({
        'fcmToken': token,
      });
      _logger
          .d("Servicer FCM Token ažuriran: $token za servicerId: $servicerId");
    } catch (e) {
      _logger.e("Neuspjelo ažuriranje Servicer FCM Tokena: $e");
    }
  }

  /// Inicijalizira ServicerService za ažuriranje FCM tokena
  void initialize() {
    updateServicerToken();

    // Slušanje promjena FCM tokena
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        String servicerId = _auth.currentUser!.uid;
        final servicerDocRef = _db.collection('servicers').doc(servicerId);

        await servicerDocRef.update({
          'fcmToken': newToken,
        });
        _logger.d(
            "Servicer FCM Token osvježen: $newToken za servicerId: $servicerId");
      } catch (e) {
        _logger.e("Neuspjelo osvježavanje Servicer FCM Tokena: $e");
      }
    });
  }

  /// Dohvaća servicer dokument iz root kolekcije 'servicers'
  Future<Map<String, dynamic>?> getServicerDocument(String servicerId) async {
    try {
      final doc = await _db.collection('servicers').doc(servicerId).get();
      if (doc.exists) {
        _logger.d("Fetched servicer document: ${doc.data()}");
        return doc.data();
      }
      _logger.d("Servicer document does not exist for servicerId: $servicerId");
      return null;
    } catch (e) {
      _logger.e("Error fetching servicer document: $e");
      return null;
    }
  }

  /// Ažurira servicer dokument s dodatnim podacima
  Future<void> updateServicerDocument({
    required String servicerId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final servicerDocRef = _db.collection('servicers').doc(servicerId);

      await servicerDocRef.update(data);
      _logger.d(
          "Servicer document updated for servicerId: $servicerId with data: $data");
    } catch (e) {
      _logger.e("Failed to update servicer document: $e");
    }
  }

  /// Uklanja servicer dokument iz root kolekcije 'servicers'
  Future<void> removeServicerDocument({
    required String servicerId,
  }) async {
    try {
      final servicerDocRef = _db.collection('servicers').doc(servicerId);

      await servicerDocRef.delete();
      _logger.d("Servicer document removed for servicerId: $servicerId");
    } catch (e) {
      _logger.e("Failed to remove servicer document: $e");
    }
  }

  // Ostale metode po potrebi
}
