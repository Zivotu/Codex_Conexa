import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'user_service.dart';
import 'subscription_service.dart';

class LocationService {
  final UserService userService = UserService();
  final Logger _logger = Logger();
  final SubscriptionService subscriptionService = SubscriptionService();

  final String apiKey = 'AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM';

  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  Future<bool> canCreateNewLocation(String userId) async {
    try {
      // Provjera postoji li već aktivna trial lokacija
      bool trialExists = await trialLocationExists(userId);
      if (trialExists) {
        _logger.i(
            "Korisnik već ima aktivan trial, ne može kreirati novu lokaciju.");
        return false;
      }

      final ownedLocationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_locations')
          .where('deleted', isEqualTo: false)
          .get();

      int activeCount = ownedLocationsSnapshot.docs.length;
      _logger.i("Korisnik ima aktivnih lokacija: $activeCount");

      // Ako nema nijedne aktivne lokacije, dopušteno je kreirati novu
      if (activeCount == 0) {
        _logger
            .i("Nema aktivnih lokacija, dopušteno je kreiranje nove lokacije.");
        return true;
      }

      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Subscriptions')
          .doc('current')
          .get();
      if (subscriptionDoc.exists) {
        final subData = subscriptionDoc.data() as Map<String, dynamic>;
        bool isActive = subData['isActive'] ?? false;
        Timestamp? endDate = subData['endDate'];
        if (isActive &&
            endDate != null &&
            endDate.toDate().isAfter(DateTime.now())) {
          int locationLimit = (subData['locationLimit'] as num?)?.toInt() ?? 0;
          _logger.i(
              "Subscription limit: $locationLimit, aktivnih lokacija: $activeCount");
          return activeCount < locationLimit;
        }
      }
      final userDoc = await _usersCollection.doc(userId).get();
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      bool trialUsed = data['trialUsed'] ?? false;
      if (!trialUsed) {
        _logger.i("Nema aktivne pretplate, trial je dostupan.");
        return true;
      }
      return false;
    } catch (e) {
      _logger.e("Error in canCreateNewLocation: $e");
      return false;
    }
  }

  CollectionReference getConstructionsCollection({
    required String countryId,
    required String cityId,
    required String locationId,
  }) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('constructions');
  }

  Future<bool> trialLocationExists(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_locations')
          .where('activationType', isEqualTo: 'trial')
          .where('activeUntil',
              isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .where('deleted', isEqualTo: false)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      _logger.e("Error checking trial location: $e");
      return false;
    }
  }

  Future<void> createLocationDocument(String countryId, String cityId,
      Map<String, dynamic> locationData) async {
    try {
      if (!locationData.containsKey('activationType')) {
        locationData['activationType'] = 'trial';
        locationData['activeUntil'] =
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));
        locationData['attachedPaymentId'] = null;
        locationData['trialPeriod'] = true;
      }
      await _createAllCountriesIfNotExist(countryId);
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationData['id'])
          .set(locationData);
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationData['id'])
          .set(locationData);
      _logger.i("Location document created: ${locationData['id']}");
    } catch (e) {
      _logger.e('Error creating location document: $e');
    }
  }

  Future<void> _createAllCountriesIfNotExist(String countryId) async {
    try {
      final allCountriesRef =
          FirebaseFirestore.instance.collection('all_countries').doc(countryId);
      final docSnapshot = await allCountriesRef.get();
      if (!docSnapshot.exists) {
        _logger.i('Creating all_countries document for countryId: $countryId');
        await allCountriesRef.set({
          'countryId': countryId,
          'createdAt': Timestamp.now(),
        });
      }
    } catch (e) {
      _logger.e('Error creating all_countries document: $e');
    }
  }

  // DODANA METODA getGeographicalData (vraca country i city)
  Future<Map<String, String>> getGeographicalData(
      double lat, double lng) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        String country = 'Unknown';
        String city = 'Unknown';
        if (results.isNotEmpty) {
          for (var component in results.first['address_components']) {
            final List types = component['types'];
            if (types.contains('country')) {
              country = component['long_name'];
            }
            if (types.contains('locality')) {
              city = component['long_name'];
            }
          }
        }
        return {
          'country': country,
          'city': city,
        };
      } else {
        throw Exception('Failed to fetch geographical data');
      }
    } catch (e) {
      _logger.e('Error fetching geographical data: $e');
      return {
        'country': 'Unknown',
        'city': 'Unknown',
      };
    }
  }

  // -------------------------
  // PROŠIRENA METODA joinLocation
  // -------------------------
  Future<void> joinLocation(
      User user, String countryId, String cityId, String locationId) async {
    final userData = await userService.getUserDocument(user);
    if (userData != null) {
      try {
        final fcmToken = await userService.getFCMToken(user) ?? '';
        final locationData =
            await getLocationDocument(countryId, cityId, locationId);
        final locationName = locationData?['name'] ?? 'Nepoznata lokacija';
        if (locationData == null) {
          _logger.w("Location $locationId does not exist or is deleted.");
          throw Exception('Lokacija ne postoji ili je obrisana.');
        }
        // Provjera je li ulazak zaključan (requiresApproval) – ako je, zahtjev se postavlja kao pending.
        bool requiresApproval = locationData['requiresApproval'] ?? false;
        Timestamp now = Timestamp.now();

        if (requiresApproval) {
          // Korisnik ulazi u stanje "pending" – dodajemo u pending_users kolekciju.
          await FirebaseFirestore.instance
              .collection('location_users')
              .doc(locationId)
              .collection('pending_users')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'username': userData['username'] ?? 'Nepoznato',
            'displayName': userData['displayName'] ?? 'Nepoznato',
            'email': userData['email'] ?? '',
            'profileImageUrl':
                userData['profileImageUrl'] ?? 'assets/images/default_user.png',
            'requestedAt': now,
            'deleted': false,
            'locationAdmin': false,
            'fcmToken': fcmToken,
            'status': 'pending',
          });

          await FirebaseFirestore.instance
              .collection('user_locations')
              .doc(user.uid)
              .collection('locations')
              .doc(locationId)
              .set({
            'locationId': locationId,
            'locationName': locationName,
            'countryId': countryId,
            'cityId': cityId,
            'requestedAt': now,
            'status': 'pending',
            'deleted': false,
            'locationAdmin': false,
          });

          final newLocationEntry = {
            'locationId': locationId,
            'locationName': locationName,
            'requestedAt': now,
            'countryId': countryId,
            'cityId': cityId,
            'locationAdmin': false,
            'status': 'pending',
            'deleted': false,
          };

          await userService.addLocationToUser(user.uid, newLocationEntry);
          _logger.i(
              "User ${user.uid} requested to join location $locationId (pending approval).");
        } else {
          // Ako nije zaključano, postupak je isti kao prije – status "joined"
          await FirebaseFirestore.instance
              .collection('location_users')
              .doc(locationId)
              .collection('users')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'username': userData['username'] ?? 'Nepoznato',
            'displayName': userData['displayName'] ?? 'Nepoznato',
            'email': userData['email'] ?? '',
            'profileImageUrl':
                userData['profileImageUrl'] ?? 'assets/images/default_user.png',
            'joinedAt': now,
            'deleted': false,
            'locationAdmin': false,
            'fcmToken': fcmToken,
            'status': 'joined',
          });
          await FirebaseFirestore.instance
              .collection('user_locations')
              .doc(user.uid)
              .collection('locations')
              .doc(locationId)
              .set({
            'locationId': locationId,
            'locationName': locationName,
            'countryId': countryId,
            'cityId': cityId,
            'joinedAt': now,
            'status': 'joined',
            'deleted': false,
            'locationAdmin': false,
          });
          final newLocationEntry = {
            'locationId': locationId,
            'locationName': locationName,
            'joinedAt': now,
            'countryId': countryId,
            'cityId': cityId,
            'locationAdmin': false,
            'status': 'joined',
            'deleted': false,
          };
          await userService.addLocationToUser(user.uid, newLocationEntry);
          _logger
              .i("User ${user.uid} successfully joined location $locationId.");
        }
      } catch (e) {
        _logger.e('Error joining location: $e');
        rethrow;
      }
    } else {
      _logger.w("User document not found for user ${user.uid}.");
      throw Exception('User document not found.');
    }
  }

  Future<Map<String, dynamic>?> getLocationDocument(
      String countryId, String cityId, String locationId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .get();
      if (doc.exists && doc.data() != null && doc.data()!['deleted'] != true) {
        return doc.data();
      } else {
        _logger
            .w("Location $locationId is marked as deleted or does not exist.");
        return null;
      }
    } catch (e) {
      _logger.e("Error fetching location document: $e");
      return null;
    }
  }

  Future<void> deleteLocationForAdmin(
      String userId, String countryId, String cityId, String locationId) async {
    _logger.d(
        "deleteLocationForAdmin called for location $locationId by user $userId");
    final locRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId);
    final allLocRef =
        FirebaseFirestore.instance.collection('locations').doc(locationId);
    final userOwnedRef = _usersCollection
        .doc(userId)
        .collection('owned_locations')
        .doc(locationId);
    final userLocationRef = FirebaseFirestore.instance
        .collection('user_locations')
        .doc(userId)
        .collection('locations')
        .doc(locationId);
    final batch = FirebaseFirestore.instance.batch();
    batch.update(locRef, {'deleted': true});
    batch.update(allLocRef, {'deleted': true});
    batch.update(userOwnedRef, {'deleted': true});
    batch.update(userLocationRef, {'deleted': true});
    await batch.commit();
    _logger.i("Location $locationId successfully marked as deleted.");
  }

  Future<void> leaveLocation(String userId, String locationId) async {
    try {
      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .collection('locations')
          .doc(locationId);
      await userLocationRef
          .update({'status': 'left', 'leftAt': Timestamp.now()});

      final userDocRef = _usersCollection.doc(userId);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic>) {
          final List<dynamic> locations = data['locations'] ?? [];
          List<dynamic> updatedLocations = locations.map((loc) {
            if (loc['locationId'] == locationId) {
              loc['status'] = 'left';
              loc['leftAt'] = Timestamp.now();
            }
            return loc;
          }).toList();

          await userDocRef.update({'locations': updatedLocations});
        }
      }

      _logger.i('User $userId successfully left location $locationId.');
    } catch (e) {
      _logger.e("Error leaving location $locationId for user $userId: $e");
      throw Exception('Error leaving location: $e');
    }
  }

  Stream<QuerySnapshot> getChatStream(
      String countryId, String cityId, String locationId) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot> getChatMessage(
      String countryId, String cityId, String locationId, String messageId) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('chats')
        .doc(messageId)
        .get();
  }

  DocumentReference getNewChatRef(
      String countryId, String cityId, String locationId) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('chats')
        .doc();
  }

  DocumentReference getChatMessageRef(
      String countryId, String cityId, String locationId, String messageId) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('chats')
        .doc(messageId);
  }
}
