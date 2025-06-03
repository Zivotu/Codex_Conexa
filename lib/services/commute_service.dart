import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_model.dart';

class CommuteService {
  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Zamijenite s vašim ključem ili dohvatite iz .env ako preferirate.
  static const String googleApiKey = "AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM";

  Future<List<Ride>> getAvailableRides(
    GeoPoint userLocation,
    double radiusInKm,
    String userId,
  ) async {
    try {
      final docs = await _firestore.collection('rideshare').get();
      final rides = docs.docs.map((doc) => Ride.fromFirestore(doc)).toList();
      final filtered = <Ride>[];

      for (var ride in rides) {
        final distanceMeters = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          ride.startLocation.latitude,
          ride.startLocation.longitude,
        );
        final distanceKm = distanceMeters / 1000.0;

        bool isRecurringMatch = true;
        final today = DateTime.now();
        final todayName = _dayName(today.weekday);

        if (ride.recurringDays.isNotEmpty &&
            !ride.recurringDays.contains(todayName)) {
          isRecurringMatch = false;
        }

        bool isUserPassenger = ride.passengers.contains(userId);

        if ((distanceKm <= radiusInKm &&
                ride.seatsAvailable > 0 &&
                isRecurringMatch &&
                ride.status != RideStatus.canceled &&
                ride.status != RideStatus.completed) ||
            isUserPassenger ||
            ride.driverId == userId) {
          // Dodan uvjet za vozačevu vožnju
          filtered.add(ride);
        }
      }
      return filtered;
    } catch (e) {
      _logger.e('Greška prilikom dohvaćanja vožnji: $e');
      rethrow;
    }
  }

  String _dayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  Stream<List<Ride>> getMyRides(String userId) {
    try {
      return _firestore
          .collection('rideshare')
          .where('driverId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
      }).asyncExpand((driverRides) async* {
        final passengerSnapshot = await _firestore
            .collection('rideshare')
            .where('passengers', arrayContains: userId)
            .get();
        final passengerRides = passengerSnapshot.docs
            .map((doc) => Ride.fromFirestore(doc))
            .toList();
        final allRides = [...driverRides, ...passengerRides];
        yield allRides;
      });
    } catch (e) {
      _logger.e('Greška prilikom dohvaćanja mojih vožnji: $e');
      rethrow;
    }
  }

  Stream<List<Ride>> getHistoryRides(String userId) {
    try {
      return _firestore
          .collection('rideshare')
          .where('driverId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
      }).asyncExpand((driverDocs) async* {
        final passengerSnapshot = await _firestore
            .collection('rideshare')
            .where('passengers', arrayContains: userId)
            .get();
        final passengerDocs = passengerSnapshot.docs
            .map((doc) => Ride.fromFirestore(doc))
            .toList();

        final allRides = [...driverDocs, ...passengerDocs];
        final now = DateTime.now();

        final filtered = allRides.where((ride) {
          final isPast = ride.departureTime.isBefore(now);
          final isDone = (ride.status == RideStatus.completed ||
              ride.status == RideStatus.canceled);
          if (ride.driverId == userId) {
            return (isPast || isDone);
          } else {
            final passengerStatus = ride.passengersStatus?[userId];
            final hasFinishedForThisPassenger = passengerStatus != null &&
                passengerStatus['hasFinished'] == true;
            if (hasFinishedForThisPassenger || isDone || isPast) {
              return true;
            }
            return false;
          }
        }).toList();

        yield filtered;
      });
    } catch (e) {
      _logger.e('Greška prilikom dohvaćanja povijesti vožnji: $e');
      rethrow;
    }
  }

  Future<void> createRide(Ride ride) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(ride.rideId);
      await docRef.set(ride.toMap(), SetOptions(merge: true));
    } catch (e) {
      _logger.e('Greška prilikom kreiranja vožnje: $e');
      rethrow;
    }
  }

  Future<void> joinRideRequest(
    String rideId,
    String userId, {
    GeoPoint? exitLocation,
  }) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(rideId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("Ride does not exist.");
        }
        final data = snapshot.data() as Map<String, dynamic>;
        final passengerRequests =
            List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []);

        final existingReq =
            passengerRequests.indexWhere((elem) => elem['userId'] == userId);
        if (existingReq != -1) {
          throw Exception("Already requested or accepted.");
        }

        final newRequest = {
          'userId': userId,
          'isAccepted': false,
          'exitLocation': exitLocation,
          'requestTime': Timestamp.now(),
          'candiesDonated': 0,
          'message': '',
        };
        passengerRequests.add(newRequest);

        transaction.update(docRef, {
          'passengerRequests': passengerRequests,
          'status': 'requested',
        });
      });
    } catch (e) {
      _logger.e('Greška prilikom slanja zahtjeva: $e');
      rethrow;
    }
  }

  Future<void> stopTrackingLocation(String rideId, String passengerId) async {
    try {
      // Cilj je izbrisati sve dokumente u kolekciji praćenja lokacije za određenog putnika,
      // kako bi drugi korisnici prestali primati njegove lokacijske podatke.
      final trackingCollection = _firestore
          .collection('rideshare')
          .doc(rideId)
          .collection('tracking')
          .doc('passengers')
          .collection(passengerId);

      final snapshots = await trackingCollection.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }

      _logger.i(
          'Zaustavljeno praćenje lokacije za putnika $passengerId u vožnji $rideId.');
    } catch (e) {
      _logger.e('Greška prilikom zaustavljanja praćenja lokacije: $e');
      rethrow;
    }
  }

  Future<void> approvePassenger(
      String rideId, String passengerId, bool approve) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(rideId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Ride does not exist.");

        final data = snapshot.data() as Map<String, dynamic>;
        final passengerRequests =
            List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []);
        final passengers = List<String>.from(data['passengers'] ?? []);
        var seatsAvailable = data['seatsAvailable'] as int? ?? 0;

        final reqIndex =
            passengerRequests.indexWhere((r) => r['userId'] == passengerId);
        if (reqIndex != -1) {
          if (approve) {
            passengerRequests[reqIndex]['isAccepted'] = true;
            if (!passengers.contains(passengerId)) {
              passengers.add(passengerId);
              if (seatsAvailable > 0) seatsAvailable -= 1;
            }
          } else {
            passengerRequests.removeAt(reqIndex);
            if (passengers.contains(passengerId)) {
              passengers.remove(passengerId);
              seatsAvailable += 1;
            }
          }
        }

        transaction.update(docRef, {
          'passengerRequests': passengerRequests,
          'passengers': passengers,
          'seatsAvailable': seatsAvailable,
          'status': _statusToString(RideStatus.open),
        });
      });
    } catch (e) {
      _logger.e('Greška pri odobrenju/odbijanju putnika: $e');
      rethrow;
    }
  }

  Future<List<LatLng>> getDirectionsPolylineWithWaypoints(
      LatLng origin, LatLng destination, List<LatLng> waypoints) async {
    final polylinePoints = PolylinePoints();
    final waypointList = waypoints
        .map((waypoint) => PolylineWayPoint(
              location: "${waypoint.latitude},${waypoint.longitude}",
            ))
        .toList();

    final request = PolylineRequest(
      origin: PointLatLng(origin.latitude, origin.longitude),
      destination: PointLatLng(destination.latitude, destination.longitude),
      mode: TravelMode.driving,
      wayPoints: waypointList,
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleApiKey,
      request: request,
    );

    if (result.points.isNotEmpty) {
      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }
    return [];
  }

  Future<void> updatePassengerExitLocation(
    String rideId,
    String passengerId,
    GeoPoint exitLocation,
  ) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(rideId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Ride does not exist.");

        final data = snapshot.data() as Map<String, dynamic>;
        final passengerRequests =
            List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []);

        final reqIndex =
            passengerRequests.indexWhere((r) => r['userId'] == passengerId);
        if (reqIndex != -1) {
          passengerRequests[reqIndex]['exitLocation'] = exitLocation;
        }
        transaction.update(docRef, {
          'passengerRequests': passengerRequests,
        });
      });
    } catch (e) {
      _logger.e('Greška prilikom ažuriranja izlazne točke: $e');
      rethrow;
    }
  }

  Future<void> startTrackingLocation(String rideId, GeoPoint location,
      {bool isPassenger = false, String? passengerId}) async {
    try {
      if (isPassenger && passengerId == null) {
        throw Exception(
            "Passenger ID must be provided when tracking as passenger.");
      }

      if (isPassenger) {
        final trackingRef = _firestore
            .collection('rideshare')
            .doc(rideId)
            .collection('tracking')
            .doc('passengers')
            .collection(passengerId!)
            .doc();
        await trackingRef.set({
          'location': location,
          'timestamp': Timestamp.now(),
        });
        _logger.i('Praćenje lokacije putnika $passengerId za vožnju $rideId.');
      } else {
        final trackingRef = _firestore
            .collection('rideshare')
            .doc(rideId)
            .collection('tracking')
            .doc('driver')
            .collection('route')
            .doc();
        await trackingRef.set({
          'location': location,
          'timestamp': Timestamp.now(),
        });
        _logger.i('Praćenje lokacije vozača za vožnju $rideId.');
      }
    } catch (e) {
      _logger.e('Greška prilikom praćenja lokacije: $e');
      rethrow;
    }
  }

  Stream<List<GeoPoint>> getDriverRouteStream(String rideId) {
    final routeCol = _firestore
        .collection('rideshare')
        .doc(rideId)
        .collection('tracking')
        .doc('driver')
        .collection('route')
        .orderBy('timestamp');
    return routeCol.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc['location'] as GeoPoint).toList();
    });
  }

  Stream<List<GeoPoint>> getPassengerRouteStream(
      String rideId, String passengerId) {
    final routeCol = _firestore
        .collection('rideshare')
        .doc(rideId)
        .collection('tracking')
        .doc('passengers')
        .collection(passengerId)
        .orderBy('timestamp');
    return routeCol.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc['location'] as GeoPoint).toList();
    });
  }

  Future<void> updateRideStatus(String rideId, RideStatus status) async {
    try {
      await _firestore.collection('rideshare').doc(rideId).update({
        'status': _statusToString(status),
      });
    } catch (e) {
      _logger.e('Greška pri ažuriranju statusa: $e');
      rethrow;
    }
  }

  Future<void> giftCandiesToDriver(
    String rideId,
    String driverId,
    String fromUserId,
    int candies,
    String? message,
  ) async {
    try {
      final rideDoc = _firestore.collection('rideshare').doc(rideId);
      await _firestore.runTransaction((transaction) async {
        final rideSnapshot = await transaction.get(rideDoc);
        if (!rideSnapshot.exists) throw Exception("Ride does not exist.");

        final rideData = rideSnapshot.data() as Map<String, dynamic>;
        final passengerRequests = List<Map<String, dynamic>>.from(
            rideData['passengerRequests'] ?? []);

        // Calculate current total candies
        int currentTotalCandies = passengerRequests.fold<int>(
          0,
          (sum, item) => sum + (item['candiesDonated'] as int? ?? 0),
        );

        if (currentTotalCandies + candies > 100) {
          throw Exception("Cannot gift more than 100 candies per ride.");
        }

        // Find the request from the user
        final reqIndex =
            passengerRequests.indexWhere((r) => r['userId'] == fromUserId);
        if (reqIndex == -1) {
          throw Exception("Passenger request not found.");
        }

        // Update the candiesDonated and message
        passengerRequests[reqIndex]['candiesDonated'] =
            (passengerRequests[reqIndex]['candiesDonated'] as int? ?? 0) +
                candies;
        if (message != null && message.isNotEmpty) {
          passengerRequests[reqIndex]['message'] = message;
        }

        // Update ride document
        transaction.update(rideDoc, {
          'passengerRequests': passengerRequests,
        });

        // Update driver's candies
        final driverDoc = _firestore.collection('users').doc(driverId);
        final driverSnapshot = await transaction.get(driverDoc);
        if (!driverSnapshot.exists) {
          throw Exception("Driver user does not exist.");
        }
        final driverData = driverSnapshot.data() as Map<String, dynamic>;
        final currentDriverCandies =
            driverData['candies'] is int ? driverData['candies'] as int : 0;
        final updatedDriverCandies = currentDriverCandies + candies;

        transaction.update(driverDoc, {
          'candies': updatedDriverCandies,
        });
      });
    } catch (e) {
      _logger.e('Greška prilikom darivanja bonbona: $e');
      rethrow;
    }
  }

  Future<void> cancelRideAsDriver(String rideId) async {
    try {
      await _firestore
          .collection('rideshare')
          .doc(rideId)
          .update({'status': 'canceled'});
    } catch (e) {
      _logger.e('Greška prilikom otkazivanja vožnje (vozač): $e');
      rethrow;
    }
  }

  Future<void> cancelRideAsPassenger(String rideId, String passengerId) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(rideId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Ride does not exist.");
        final data = snapshot.data() as Map<String, dynamic>;
        final passengerRequests =
            List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []);
        final passengers = List<String>.from(data['passengers'] ?? []);

        passengerRequests.removeWhere((r) => r['userId'] == passengerId);
        if (passengers.contains(passengerId)) {
          passengers.remove(passengerId);
          final seatsAvailable = (data['seatsAvailable'] as int? ?? 0) + 1;
          transaction.update(docRef, {
            'passengerRequests': passengerRequests,
            'passengers': passengers,
            'seatsAvailable': seatsAvailable,
          });
        } else {
          transaction.update(docRef, {
            'passengerRequests': passengerRequests,
          });
        }
      });
    } catch (e) {
      _logger.e('Greška prilikom otkazivanja vožnje (putnik): $e');
      rethrow;
    }
  }

  Future<void> finishRideForPassenger(
    String rideId,
    String passengerId, {
    GeoPoint? finalLocation,
  }) async {
    try {
      final docRef = _firestore.collection('rideshare').doc(rideId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Ride does not exist.");

        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> passengersStatus =
            Map<String, dynamic>.from(data['passengersStatus'] ?? {});

        final currentPassengerStatus =
            Map<String, dynamic>.from(passengersStatus[passengerId] ?? {});
        currentPassengerStatus['hasFinished'] = true;
        currentPassengerStatus['finishTime'] = Timestamp.now();
        if (finalLocation != null) {
          currentPassengerStatus['finalLocation'] = finalLocation;
        }

        passengersStatus[passengerId] = currentPassengerStatus;

        transaction.update(docRef, {
          'passengersStatus': passengersStatus,
        });
      });
    } catch (e) {
      _logger.e('Greška prilikom završavanja vožnje za putnika: $e');
      rethrow;
    }
  }

  Future<void> rateUser(
    String ratedUserId,
    String fromUserId,
    double rating, {
    String? comment,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(ratedUserId)
          .collection('ratings')
          .doc();
      await docRef.set({
        'fromUserId': fromUserId,
        'rating': rating,
        'comment': comment ?? '',
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      _logger.e('Greška prilikom ocjenjivanja: $e');
      rethrow;
    }
  }

  Future<List<LatLng>> getDirectionsPolyline(
      LatLng origin, LatLng destination) async {
    final polylinePoints = PolylinePoints();
    final request = PolylineRequest(
      origin: PointLatLng(origin.latitude, origin.longitude),
      destination: PointLatLng(destination.latitude, destination.longitude),
      mode: TravelMode.driving,
      wayPoints: [],
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleApiKey,
      request: request,
    );

    if (result.points.isNotEmpty) {
      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }
    return [];
  }

  String _statusToString(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'requested';
      case RideStatus.active:
        return 'active';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.canceled:
        return 'canceled';
      case RideStatus.open:
      default:
        return 'open';
    }
  }
}
