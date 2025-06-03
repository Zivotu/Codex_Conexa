import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class LocationService {
  final UserService userService = UserService();

  Future<void> createLocationDocument(String countryId, String cityId,
      Map<String, dynamic> locationData) async {
    await FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationData['id'])
        .set(locationData);
  }

  Future<void> joinLocation(
      User user, String countryId, String cityId, String locationId) async {
    final userData = await userService.getUserDocument(user);
    if (userData != null) {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('users')
          .doc(user.uid)
          .set(userData);
    }
  }

  Future<Map<String, dynamic>?> getLocationDocument(
      String countryId, String cityId, String locationId) async {
    final doc = await FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .get();
    return doc.data();
  }
}
