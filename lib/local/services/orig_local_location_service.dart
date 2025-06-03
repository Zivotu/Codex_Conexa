import 'package:cloud_firestore/cloud_firestore.dart';

class LocalLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPostsStream(
      String countryId, String cityId, String neighborhoodId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';
    cityId = cityId.isNotEmpty ? cityId : 'default_city';
    neighborhoodId =
        neighborhoodId.isNotEmpty ? neighborhoodId : 'default_neighborhood';

    return _firestore
        .collection('local_community')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('neighborhoods')
        .doc(neighborhoodId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getCityPostsStream(String countryId, String cityId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';
    cityId = cityId.isNotEmpty ? cityId : 'default_city';

    return _firestore
        .collectionGroup('posts')
        .where('city', isEqualTo: cityId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getCountryPostsStream(String countryId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';

    return _firestore
        .collectionGroup('posts')
        .where('country', isEqualTo: countryId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Query getPostsQuery(String countryId, String cityId, String neighborhoodId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';
    cityId = cityId.isNotEmpty ? cityId : 'default_city';
    neighborhoodId =
        neighborhoodId.isNotEmpty ? neighborhoodId : 'default_neighborhood';

    return _firestore
        .collection('local_community')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('neighborhoods')
        .doc(neighborhoodId)
        .collection('posts')
        .orderBy('createdAt', descending: true);
  }

  Query getCityPostsQuery(String countryId, String cityId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';
    cityId = cityId.isNotEmpty ? cityId : 'default_city';

    return _firestore
        .collectionGroup('posts')
        .where('city', isEqualTo: cityId)
        .orderBy('createdAt', descending: true);
  }

  Query getCountryPostsQuery(String countryId) {
    countryId = countryId.isNotEmpty ? countryId : 'default_country';

    return _firestore
        .collectionGroup('posts')
        .where('country', isEqualTo: countryId)
        .orderBy('createdAt', descending: true);
  }
}
