// lib/local/services/post_correction_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../services/location_service.dart';
import '../constants/location_constants.dart'; // NOVI import za konstante

class PostCorrectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger(); // Osigurajte da koristite ispravan Logger

  // Metoda za pronalazak i ispravljanje postova s Unknown lokacijama
  Future<void> correctUnknownLocationPosts() async {
    try {
      final String currentYear = DateTime.now().year.toString();
      final String currentMonth =
          DateTime.now().month.toString().padLeft(2, '0');
      final String collectionGroupName = 'posts_${currentYear}_$currentMonth';

      _logger
          .i('Migrating documents in collection group: $collectionGroupName');

      // Pretraživanje postova s 'unknown_*' u bilo kojoj razini
      // 1) Postovi s nepoznatom državom
      QuerySnapshot unknownCountrySnapshot = await _firestore
          .collectionGroup(collectionGroupName)
          .where('localCountryId', isEqualTo: LocationConstants.UNKNOWN_COUNTRY)
          .get();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> unknownPosts =
          unknownCountrySnapshot.docs
              .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      // 2) Postovi s nepoznatim gradom
      QuerySnapshot unknownCitySnapshot = await _firestore
          .collectionGroup(collectionGroupName)
          .where('localCityId', isEqualTo: LocationConstants.UNKNOWN_CITY)
          .get();

      unknownPosts.addAll(unknownCitySnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>());

      // 3) Postovi s nepoznatim kvartom
      QuerySnapshot unknownNeighborhoodSnapshot = await _firestore
          .collectionGroup(collectionGroupName)
          .where('localNeighborhoodId',
              isEqualTo: LocationConstants.UNKNOWN_NEIGHBORHOOD)
          .get();

      unknownPosts.addAll(unknownNeighborhoodSnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>());

      // 4) Postovi s općom nepoznatom lokacijom
      QuerySnapshot unknownLocationSnapshot = await _firestore
          .collectionGroup(collectionGroupName)
          .where('localLocationId',
              isEqualTo: LocationConstants.UNKNOWN_LOCATION)
          .get();

      unknownPosts.addAll(unknownLocationSnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>());

      // 5) Postovi označeni samo kao "Unknown"
      QuerySnapshot generalUnknownSnapshot = await _firestore
          .collectionGroup(collectionGroupName)
          .where('localLocationId', isEqualTo: LocationConstants.UNKNOWN)
          .get();

      unknownPosts.addAll(generalUnknownSnapshot.docs
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>());

      if (unknownPosts.isEmpty) {
        _logger.i('Nema postova za ispraviti u Unknown lokacijama.');
        return;
      }

      _logger.i('Pronađeno ${unknownPosts.length} postova za migraciju.');

      for (var doc in unknownPosts) {
        Map<String, dynamic> postData = doc.data();
        String postId = doc.id;

        // Ako post nema geo lokaciju, ne možemo ga ispraviti
        if (!postData.containsKey('postGeoLocation')) {
          _logger.w(
              'Post $postId nema postGeoLocation; ne možemo ispraviti lokaciju.');
          continue;
        }

        GeoPoint postGeoLocation = postData['postGeoLocation'] as GeoPoint;

        // Dohvaćanje točnih geografskih podataka
        final geoData = await _locationService.getGeographicalData(
            postGeoLocation.latitude, postGeoLocation.longitude);

        String correctedCountry =
            geoData['country'] ?? LocationConstants.UNKNOWN_COUNTRY;
        String correctedCity =
            geoData['city'] ?? LocationConstants.UNKNOWN_CITY;
        String correctedNeighborhood =
            geoData['neighborhood'] ?? LocationConstants.UNKNOWN_NEIGHBORHOOD;

        // Ako je post označen samo kao "Unknown" i nakon korekcije ostaje "Unknown", preskačemo
        if (postData.containsKey('localLocationId') &&
            postData['localLocationId'] == LocationConstants.UNKNOWN &&
            correctedCountry == LocationConstants.UNKNOWN_COUNTRY &&
            correctedCity == LocationConstants.UNKNOWN_CITY &&
            correctedNeighborhood == LocationConstants.UNKNOWN_NEIGHBORHOOD) {
          _logger.w(
              'Neuspjelo ispravljanje posta s ID-em $postId, lokacija ostaje "Unknown".');
          continue;
        }

        // Kreiramo novi post u ispravnoj lokaciji
        await _movePostToCorrectLocation(
          postId,
          postData,
          correctedCountry,
          correctedCity,
          correctedNeighborhood,
          doc.reference,
        );
      }

      // Učitavanje novih podataka iz Firestore nakon premještanja (opcionalno)
      await _reloadPostsAfterCorrection();
    } catch (e) {
      _logger.e('Greška prilikom ispravljanja postova: $e');
    }
  }

  // Metoda za premještanje posta u ispravnu lokaciju
  Future<void> _movePostToCorrectLocation(
    String postId,
    Map<String, dynamic> postData,
    String country,
    String city,
    String neighborhood,
    DocumentReference originalRef,
  ) async {
    try {
      // Ažuriraj postData s ispravnim nazivima
      postData['localCountryId'] = country;
      postData['localCityId'] = city;
      postData['localNeighborhoodId'] = neighborhood;
      postData['corrected'] = true; // oznaka da je post ispravljen

      String newCollectionPath;
      if (postData.containsKey('localLocationId') &&
          postData['localLocationId'] == LocationConstants.UNKNOWN) {
        // Putanja za "Unknown" lokacije
        newCollectionPath =
            'local_community/${LocationConstants.UNKNOWN}/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';
      } else if (country == LocationConstants.UNKNOWN_COUNTRY &&
          city == LocationConstants.UNKNOWN_CITY &&
          neighborhood == LocationConstants.UNKNOWN_NEIGHBORHOOD) {
        // Putanja za opću nepoznatu lokaciju
        newCollectionPath =
            'local_community/${LocationConstants.UNKNOWN_LOCATION}/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';
      } else {
        // Putanja za specifičnu lokaciju
        newCollectionPath =
            'local_community/$country/cities/$city/neighborhoods/$neighborhood/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';
      }

      // Koristimo batch ili transakciju radi konzistentnosti
      WriteBatch batch = _firestore.batch();

      // Novi dokument u ispravnoj lokaciji
      DocumentReference newDocRef =
          _firestore.collection(newCollectionPath).doc(postId);
      batch.set(newDocRef, postData);

      // Brisanje originalnog dokumenta
      batch.delete(originalRef);

      // Izvršavamo batch
      await batch.commit();

      _logger.i(
          'Post $postId premješten u $newCollectionPath i originalni obrisan.');
    } catch (e) {
      _logger.e('Greška prilikom premještanja posta $postId: $e');
    }
  }

  // Metoda za ponovno učitavanje postova nakon ispravka (opcionalno)
  Future<void> _reloadPostsAfterCorrection() async {
    // Ovdje možete pozvati refresh na nekom streamu ili obavijestiti UI sloj
    // da ponovo učita podatke. Primjer:
    // await someProviderOrNotifier.refreshPosts();
  }
}
