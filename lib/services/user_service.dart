import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _servicersCollection =
      FirebaseFirestore.instance.collection('servicers');

  /// Getter za trenutnog korisnika
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Kreira korisnički dokument s deviceId
  Future<void> createUserDocument(
    User user,
    String geoCountryId,
    String geoCityId,
    String geoNeighborhoodId,
    String deviceId, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final userData = {
        'userId': user.uid,
        'email': user.email ?? '',
        'displayName': additionalData?['displayName'] ?? '',
        'lastName': additionalData?['lastName'] ?? '',
        'username': additionalData?['username'] ?? '',
        'floor': additionalData?['floor'] ?? '',
        'apartmentNumber': additionalData?['apartmentNumber'] ?? '',
        'phone': additionalData?['phone'] ?? '',
        'address': additionalData?['address'] ?? '',
        'profileImageUrl': additionalData?['profileImageUrl'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'geoCountryId': geoCountryId,
        'geoCityId': geoCityId,
        'geoNeighborhoodId': geoNeighborhoodId,
        'balance': 0,
        'transactions': [],
        'locations': additionalData?['locations'] ?? [],
        'lastVisit': FieldValue.serverTimestamp(),
        // 'fcmToken': additionalData?['fcmToken'] ?? '', // dodaje se kasnije
        'isAnonymous': additionalData?['isAnonymous'] ?? false,
        'userType': additionalData?['userType'] ?? 'user',
        'age': additionalData?['age'],
        'education': additionalData?['education'] ?? 'Unknown',
        'occupation': additionalData?['occupation'] ?? 'Unknown',
        'platform': additionalData?['platform'] ?? 'Unknown',
        'appVersion': additionalData?['appVersion'] ?? '1.0.0',
        'deviceId': deviceId,
        'blocked': additionalData?['blocked'] ?? false,
        'parkingPoints': 0,
      };

      await _usersCollection.doc(user.uid).set(userData);
      _logger.d("User document created: $userData");
    } catch (e) {
      _logger.e("Error creating user document: $e");
    }
  }

  /// Ažurira korisnički dokument s dodatnim podacima
  Future<void> updateUserDocument(User user, Map<String, dynamic> data) async {
    try {
      final userDocRef = _usersCollection.doc(user.uid);
      await userDocRef.update(data);
      _logger.d("User document updated: $data");
    } catch (e) {
      _logger.e("Failed to update user document: $e");
    }
  }

  Future<void> updateUserPoints(String userId, int delta) async {
    try {
      final userRef = _usersCollection.doc(userId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          int currentPoints = data['parkingPoints'] ?? 0;
          transaction.update(userRef, {'parkingPoints': currentPoints + delta});
        }
      });
      _logger.d("Updated user $userId parking points by $delta");
    } catch (e) {
      _logger.e("Failed to update user points: $e");
    }
  }

  /// Ažurira FCM token za korisnika u 'users' i 'servicers' kolekciji.
  Future<void> updateFcmToken(String userId, String? fcmToken) async {
    if (fcmToken == null || fcmToken.isEmpty) {
      _logger.w("FCM token je null ili prazan, ne ažuriram.");
      return;
    }

    WriteBatch batch = FirebaseFirestore.instance.batch();

    final userDocRef = _usersCollection.doc(userId);
    batch.update(userDocRef, {'fcmToken': fcmToken});

    final servicerDocRef = _servicersCollection.doc(userId);

    final servicerDocSnapshot = await servicerDocRef.get();
    if (servicerDocSnapshot.exists) {
      batch.update(servicerDocRef, {'fcmToken': fcmToken});
    } else {
      _logger.d(
          "Servicer document does not exist for user $userId, skipping update.");
    }

    try {
      await batch.commit();
      _logger.d("FCM Token updated for user $userId: $fcmToken");
    } catch (e) {
      _logger.e("Failed to update FCM token for user $userId: $e");
    }
  }

  /// Uklanja nevažeće FCM tokene iz Firestore
  Future<void> removeInvalidFcmTokens(List<String> invalidTokens) async {
    try {
      for (var token in invalidTokens) {
        final snapshot =
            await _usersCollection.where('fcmToken', isEqualTo: token).get();

        for (var doc in snapshot.docs) {
          await doc.reference.update({'fcmToken': FieldValue.delete()});
          _logger.d("Invalid FCM token removed: $token for user ${doc.id}");
        }
      }
    } catch (e) {
      _logger.e("Error removing invalid FCM tokens: $e");
    }
  }

  /// Dohvaća korisnički dokument
  Future<Map<String, dynamic>?> getUserDocument(User user) async {
    try {
      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          _logger.d("Fetched user document: $data");
          return data;
        } else {
          _logger.e(
              "User document is not a Map<String, dynamic> for user: ${user.uid}");
          return null;
        }
      }
      _logger.d("User document does not exist for user: ${user.uid}");
      return null;
    } catch (e) {
      _logger.e("Error fetching user document: $e");
      return null;
    }
  }

  /// Dohvaća FCM token korisnika
  Future<String?> getFCMToken(User user) async {
    try {
      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          _logger.d("Fetched FCM token: ${data['fcmToken']}");
          return data['fcmToken'] as String?;
        }
        _logger.e(
            "User document is not a Map<String, dynamic> for user: ${user.uid}");
        return null;
      }
      _logger.d("User document does not exist for user: ${user.uid}");
      return null;
    } catch (e) {
      _logger.e("Error fetching FCM token: $e");
      return null;
    }
  }

  /// Dohvaća korisnički dokument po ID-u
  Future<Map<String, dynamic>?> getUserDocumentById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Dodaje novu lokaciju u `locations` polje korisnika
  Future<void> addLocationToUser(
      String userId, Map<String, dynamic> locationData) async {
    try {
      final userRef = _usersCollection.doc(userId);
      await userRef.update({
        'locations': FieldValue.arrayUnion([locationData]),
      });
      _logger.d("Added location to user's locations: $locationData");
    } catch (e) {
      _logger.e("Failed to add location to user: $e");
    }
  }

  /// Ažurira cijeli unos lokacije u polju 'locations' korisnika
  Future<void> updateLocationEntry(String userId, String locationId,
      Map<String, dynamic> updatedData) async {
    try {
      final userDocRef = _usersCollection.doc(userId);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic> && data['locations'] != null) {
          List<dynamic> locations = data['locations'];
          bool updated = false;
          for (int i = 0; i < locations.length; i++) {
            var loc = locations[i];
            if (loc is Map<String, dynamic> &&
                loc['locationId'] == locationId) {
              locations[i] = {...loc, ...updatedData};
              updated = true;
              break;
            }
          }
          if (updated) {
            await userDocRef.update({'locations': locations});
            _logger.d(
                "Updated location entry for user $userId: locationId=$locationId");
          }
        }
      }
    } catch (e) {
      _logger.e("Failed to update location entry: $e");
    }
  }

  /// Ažurira status lokacije u `locations` polju korisnika
  Future<void> updateLocationStatus(
      String userId, String locationId, String status) async {
    try {
      final userDocRef = _usersCollection.doc(userId);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic> && data['locations'] != null) {
          List<dynamic> locations = data['locations'];
          bool updated = false;
          for (var loc in locations) {
            if (loc is Map<String, dynamic> &&
                loc['locationId'] == locationId) {
              loc['status'] = status;
              if (status == 'left' || status == 'deleted') {
                loc['leftAt'] = Timestamp.now();
              }
              if (status == 'deleted') {
                loc['deleted'] = true;
                loc['deletedAt'] = Timestamp.now();
              }
              updated = true;
            }
          }
          if (updated) {
            await userDocRef.update({'locations': locations});
            _logger.d(
                "Updated location status for user $userId: locationId=$locationId, status=$status");
          }
        }
      }
    } catch (e) {
      _logger.e("Failed to update location status: $e");
    }
  }

  /// Uklanja lokaciju iz `locations` polja korisnika
  Future<void> removeLocationFromUser(String userId, String locationId) async {
    try {
      final userDocRef = _usersCollection.doc(userId);
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic> && data['locations'] != null) {
          List<dynamic> locations = data['locations'];
          Map<String, dynamic>? locationToRemove;
          for (var loc in locations) {
            if (loc is Map<String, dynamic> &&
                loc['locationId'] == locationId) {
              locationToRemove = Map<String, dynamic>.from(loc);
              break;
            }
          }
          if (locationToRemove != null) {
            await userDocRef.update({
              'locations': FieldValue.arrayRemove([locationToRemove]),
            });
            _logger.d(
                "Removed location from user's locations: locationId=$locationId");
          } else {
            _logger.w(
                "Location with locationId=$locationId not found in user's locations.");
          }
        }
      }
    } catch (e) {
      _logger.e("Failed to remove location from user: $e");
    }
  }

  /// Korisnik napušta lokaciju
  Future<void> leaveLocation(String userId, String locationId) async {
    try {
      _logger.d(
          "Starting leaveLocation for user $userId and location $locationId");

      // Ažuriranje statusa u `users` kolekciji
      await updateLocationStatus(userId, locationId, 'left');

      // Ažuriranje statusa u 'user_locations' kolekciji
      final userLocationDoc = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .collection('locations')
          .doc(locationId);

      final userLocationSnapshot = await userLocationDoc.get();
      if (userLocationSnapshot.exists) {
        _logger.d("User location document exists, marking as left...");
        await userLocationDoc.update({'status': 'left'});
        _logger.d(
            "Location $locationId marked as left in user_locations for user $userId.");
      } else {
        _logger.e("User location document does not exist.");
      }
    } catch (e) {
      _logger.e("Error leaving location $locationId for user $userId: $e");
    }
  }

  /// Administrator označava lokaciju kao obrisanu (SOFT DELETE) za sve
  Future<void> deleteLocationForAdmin(
      String userId, String countryId, String cityId, String locationId) async {
    try {
      _logger.d(
          "Starting deleteLocationForAdmin for location $locationId by user $userId");

      final batch = FirebaseFirestore.instance.batch();

      // 1) Glavna lokacija: 'countries/{countryId}/cities/{cityId}/locations/{locationId}'
      final locationRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId);

      final locationSnapshot = await locationRef.get();
      if (!locationSnapshot.exists) {
        throw Exception('Dokument lokacije ne postoji: $locationId');
      }

      batch.update(locationRef, {
        'deleted': true,
        'deletedAt': Timestamp.now(),
      });

      // 2) 'all_locations/{locationId}'
      final allLocationsRef = FirebaseFirestore.instance
          .collection('all_locations')
          .doc(locationId);

      final allLocDoc = await allLocationsRef.get();
      if (allLocDoc.exists) {
        batch.update(allLocationsRef, {
          'deleted': true,
          'deletedAt': Timestamp.now(),
        });
      } else {
        _logger.w("Location $locationId does not exist in all_locations.");
      }

      // 3) location_users/{locationId}/users/{uid}
      final locUsersQuery = await FirebaseFirestore.instance
          .collection('location_users')
          .doc(locationId)
          .collection('users')
          .get();

      for (var userDoc in locUsersQuery.docs) {
        // (a) U samom location_users
        batch.update(userDoc.reference, {
          'deleted': true,
        });

        // (b) U user_locations/{uid}/locations/{locationId}
        final userLocationDoc = FirebaseFirestore.instance
            .collection('user_locations')
            .doc(userDoc.id)
            .collection('locations')
            .doc(locationId);
        final locSnap = await userLocationDoc.get();
        if (locSnap.exists) {
          batch.update(userLocationDoc, {
            'status': 'deleted',
            'deleted': true,
            'deletedAt': Timestamp.now(),
          });
        }
      }

      // 4) Polje `locations` unutar kolekcije `users`
      final usersSnapshot = await _usersCollection.get();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['locations'] != null) {
          List<dynamic> locations = userData['locations'];
          bool updated = false;
          for (var loc in locations) {
            if (loc is Map<String, dynamic> &&
                loc['locationId'] == locationId &&
                loc['deleted'] != true) {
              loc['status'] = 'deleted';
              loc['deleted'] = true;
              loc['deletedAt'] = Timestamp.now();
              updated = true;
            }
          }
          if (updated) {
            batch.update(userDoc.reference, {'locations': locations});
          }
        }
      }

      await batch.commit();
      _logger.d("Location $locationId marked as deleted for all references.");
    } catch (e) {
      _logger.e("Error deleting location $locationId for admin $userId: $e");
    }
  }

  /// Ažurira korisničku bilancu
  Future<void> updateUserBalance(User user, int amount) async {
    try {
      final DocumentReference userRef = _usersCollection.doc(user.uid);
      final DocumentSnapshot userDoc = await userRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic>) {
          final currentBalance = data['balance'] ?? 0;
          final transactions =
              List<Map<String, dynamic>>.from(data['transactions'] ?? []);
          final timestamp = Timestamp.now();
          transactions.add({
            'amount': amount,
            'timestamp': timestamp,
            'type': amount > 0 ? 'add' : 'reset',
          });

          await userRef.update({
            'balance': currentBalance + amount,
            'transactions': transactions,
          });
          _logger.d("User balance updated: ${currentBalance + amount}");
        }
      }
    } catch (e) {
      _logger.e("Failed to update user balance: $e");
    }
  }

  Future<void> resetUserBalance(User user) async {
    try {
      final DocumentReference userRef = _usersCollection.doc(user.uid);
      final DocumentSnapshot userDoc = await userRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic>) {
          final transactions =
              List<Map<String, dynamic>>.from(data['transactions'] ?? []);
          final timestamp = Timestamp.now();
          transactions.add({
            'amount': -(data['balance'] ?? 0),
            'timestamp': timestamp,
            'type': 'reset',
          });

          await userRef.update({
            'balance': 0,
            'transactions': transactions,
          });
          _logger.d("User balance reset.");
        }
      }
    } catch (e) {
      _logger.e("Failed to reset user balance: $e");
    }
  }

  /// Ažurira korisničke metrike (npr. lajkovi)
  Future<void> updateUserMetrics(
      String userId, String postId, int likeChange) async {
    try {
      final userMetricsRef =
          _usersCollection.doc(userId).collection('user_metrics').doc(postId);

      final metricsDoc = await userMetricsRef.get();

      if (metricsDoc.exists) {
        await userMetricsRef.update({
          'likes': FieldValue.increment(likeChange),
        });
      } else {
        await userMetricsRef.set({
          'postId': postId,
          'likes': likeChange,
        });
      }
      _logger.d(
          "User metrics updated for user $userId and post $postId with likeChange $likeChange");
    } catch (e) {
      _logger.e("Failed to update user metrics: $e");
    }
  }

  /// Ažurira vremensku oznaku posljednje posjete
  Future<void> updateLastVisitTimestamp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _usersCollection
            .doc(user.uid)
            .update({'lastVisit': FieldValue.serverTimestamp()});
        _logger.d("User last visit timestamp updated.");
      } catch (e) {
        _logger.e("Failed to update last visit timestamp: $e");
      }
    }
  }

  /// Dohvaća vremensku oznaku posljednje posjete
  Future<Timestamp?> getLastVisitTimestamp() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _usersCollection.doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data is Map<String, dynamic> && data['lastVisit'] is Timestamp) {
            return data['lastVisit'] as Timestamp;
          }
        }
      }
      return null;
    } catch (e) {
      _logger.e("Failed to get last visit timestamp: $e");
      return null;
    }
  }

  /// Dohvaća status `locationAdmin` za korisnika u određenoj lokaciji
  Future<bool> getLocationAdminStatus(String userId, String locationId) async {
    try {
      final doc = await _firestore
          .collection('location_users')
          .doc(locationId)
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          bool isAdmin = data['locationAdmin'] ?? false;
          _logger.d("User $userId admin for location $locationId: $isAdmin");
          return isAdmin;
        }
      }
      _logger.w(
          "User doc does not exist or 'locationAdmin' field missing for user $userId at location $locationId.");
      return false;
    } catch (e) {
      _logger.e("Error fetching location admin status for user $userId: $e");
      return false;
    }
  }

  /// Provjerava je li uređaj blokiran
  Future<bool> isDeviceBlocked(String deviceId) async {
    try {
      final doc =
          await _firestore.collection('blocked_devices').doc(deviceId).get();

      return doc.exists;
    } catch (e) {
      _logger.e("Failed to check if device is blocked: $e");
      return false;
    }
  }

  /// Blokira korisnika i njegov uređaj
  Future<void> blockUser(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic>) {
          String? deviceId = data['deviceId'] as String?;
          if (deviceId != null) {
            await _firestore.collection('blocked_devices').doc(deviceId).set({
              'deviceId': deviceId,
              'blockedAt': FieldValue.serverTimestamp(),
            });
            _logger.d(
                "Device $deviceId has been blocked along with user $userId.");
          }
        }
      }
      await _usersCollection.doc(userId).update({'blocked': true});
      _logger.d("User $userId has been blocked.");
    } catch (e) {
      _logger.e("Failed to block user $userId: $e");
    }
  }

  /// Deblokira korisnika i njegov uređaj
  Future<void> unblockUser(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data is Map<String, dynamic>) {
          String? deviceId = data['deviceId'] as String?;
          if (deviceId != null) {
            await _firestore
                .collection('blocked_devices')
                .doc(deviceId)
                .delete();
            _logger.d(
                "Device $deviceId has been unblocked along with user $userId.");
          }
        }
      }
      await _usersCollection.doc(userId).update({'blocked': false});
      _logger.d("User $userId has been unblocked.");
    } catch (e) {
      _logger.e("Failed to unblock user $userId: $e");
    }
  }

  /// Ažurira polje `locationAdmin` za korisnika na svim relevantnim mjestima
  Future<void> updateLocationAdminStatus({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required bool isAdmin,
  }) async {
    WriteBatch batch = _firestore.batch();

    // Referenca na glavnu lokaciju - 'countries/.../locations/.../users/<userId>'
    DocumentReference mainUserDoc = _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('users')
        .doc(userId);

    batch.update(mainUserDoc, {'locationAdmin': isAdmin});

    // 'location_users/{locationId}/users/{userId}'
    DocumentReference locationUsersDoc = _firestore
        .collection('location_users')
        .doc(locationId)
        .collection('users')
        .doc(userId);

    batch.update(locationUsersDoc, {'locationAdmin': isAdmin});

    // 'user_locations/{userId}/locations/{locationId}'
    DocumentReference userLocationsDoc = _firestore
        .collection('user_locations')
        .doc(userId)
        .collection('locations')
        .doc(locationId);
    // Dodajemo ažuriranje u globalnu kolekciju 'users'
    DocumentReference globalUserDoc = _usersCollection.doc(userId);
    batch.update(globalUserDoc, {'locationAdmin': isAdmin});

    batch.update(userLocationsDoc, {'locationAdmin': isAdmin});

    try {
      await batch.commit();
      _logger.d(
          "Updated 'locationAdmin' for user $userId to $isAdmin on all relevant collections.");
    } catch (e) {
      _logger.e("Failed to update 'locationAdmin' for user $userId: $e");
      rethrow;
    }
  }

  /// Dohvaća saldo korisnika (balance)
  Future<double> getUserBalance(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('balance')) {
          return (data['balance'] as num).toDouble();
        }
      }
    } catch (e) {
      _logger.e("Failed to get user balance: $e");
    }
    return 0.0; // Defaultna vrijednost ako nešto pođe po zlu
  }

  /// Oduzima iznos od balansa korisnika
  Future<bool> deductUserBalance(String userId, double amount) async {
    try {
      return await FirebaseFirestore.instance
          .runTransaction((transaction) async {
        DocumentReference userRef = _usersCollection.doc(userId);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception("User does not exist!");
        }

        final data = userSnapshot.data() as Map<String, dynamic>?;

        double currentBalance = 0.0;
        if (data != null && data.containsKey('balance')) {
          currentBalance = (data['balance'] as num).toDouble();
        }

        if (currentBalance < amount) {
          throw Exception("Insufficient balance!");
        }

        double newBalance = currentBalance - amount;
        transaction.update(userRef, {'balance': newBalance});

        return true;
      });
    } catch (e) {
      _logger.e("Failed to deduct user balance: $e");
      return false;
    }
  }

  /// Dodaje iznos na balans korisnika
  Future<bool> addUserBalance(String userId, double amount) async {
    try {
      await _usersCollection.doc(userId).update({
        'balance': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      _logger.e("Failed to add user balance: $e");
      return false;
    }
  }

  // ====================================================
  // NOVE METODE ZA KICK/UNBLOCK KORISNIKA IZ LOKACIJE
  // ====================================================

  /// Izbacuje korisnika iz lokacije tako da se njegov status postavlja na "kicked"
  Future<void> kickUserFromLocation(String userId, String locationId) async {
    try {
      // Ažuriramo u kolekciji 'user_locations'
      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .collection('locations')
          .doc(locationId);
      await userLocationRef.update({
        'status': 'kicked',
        'kickedAt': FieldValue.serverTimestamp(),
        'locationAdmin': false,
      });

      // Ažuriramo u kolekciji 'location_users'
      final locationUserRef = FirebaseFirestore.instance
          .collection('location_users')
          .doc(locationId)
          .collection('users')
          .doc(userId);
      await locationUserRef.update({
        'status': 'kicked',
        'kickedAt': FieldValue.serverTimestamp(),
        'locationAdmin': false,
      });
      _logger.d("User $userId kicked from location $locationId");
    } catch (e) {
      _logger.e("Failed to kick user $userId from location $locationId: $e");
      rethrow;
    }
  }

  /// Odblokira korisnika iz lokacije tako da se njegov status postavlja na "left" (što omogućava ponovno pridruživanje)
  Future<void> unblockUserFromLocation(String userId, String locationId) async {
    try {
      // Ažuriramo u kolekciji 'user_locations' – status postavljamo na "left" i brišemo timestamp za kick
      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .collection('locations')
          .doc(locationId);
      await userLocationRef.update({
        'status': 'left',
        'kickedAt': FieldValue.delete(),
      });

      // Ažuriramo u kolekciji 'location_users' na isti način
      final locationUserRef = FirebaseFirestore.instance
          .collection('location_users')
          .doc(locationId)
          .collection('users')
          .doc(userId);
      await locationUserRef.update({
        'status': 'left',
        'kickedAt': FieldValue.delete(),
      });
      _logger.d("User $userId unblocked from location $locationId");
    } catch (e) {
      _logger.e("Failed to unblock user $userId from location $locationId: $e");
      rethrow;
    }
  }
}
