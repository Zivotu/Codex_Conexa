import 'package:cloud_firestore/cloud_firestore.dart';

class CityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createCityDocument(
      String countryId, Map<String, dynamic> cityData) async {
    final cityDoc = _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityData['cityId']);

    final docSnapshot = await cityDoc.get();

    if (!docSnapshot.exists) {
      await cityDoc.set(cityData);
    }
  }

  Future<void> updateCityDocument(
      String countryId, String cityId, Map<String, dynamic> data) async {
    final cityDoc = _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId);

    await cityDoc.update(data);
  }

  Future<Map<String, dynamic>?> getCityDocument(
      String countryId, String cityId) async {
    final cityDoc = _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId);

    final docSnapshot = await cityDoc.get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }
}
