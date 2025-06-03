// lib/services/parking_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/parking_slot.dart';
import '../models/parking_request.dart';

final Logger _logger = Logger();

class ParkingService {
  Future<void> joinParkingCommunity({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required List<ParkingSlot> parkingSlots,
  }) async {
    try {
      final parkingRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId);

      await parkingRef.set({
        'userId': userId,
      });

      for (var slot in parkingSlots) {
        await parkingRef
            .collection('parkingSlots')
            .doc(slot.id)
            .set(slot.toMap());
      }

      _logger.i(
          "User $userId joined parking community with slots: ${parkingSlots.map((s) => s.name).toList()}");
    } catch (e) {
      _logger.e("Error joining parking community: $e");
      rethrow;
    }
  }

  Future<bool> isUserJoined({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      _logger.e("Error checking if user is joined: $e");
      rethrow;
    }
  }

  Future<List<ParkingSlot>> getUserParkingSlots({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .get();

      List<ParkingSlot> slots = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ParkingSlot.fromMap(data, doc.id);
      }).toList();

      return slots;
    } catch (e) {
      _logger.e("Error getting user parking slots: $e");
      rethrow;
    }
  }

  Future<void> addParkingSlot({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotName,
  }) async {
    try {
      final parkingSlotsRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots');

      DocumentReference newSlotRef = parkingSlotsRef.doc();
      String newSlotId = newSlotRef.id;

      ParkingSlot newSlot = ParkingSlot(
        id: newSlotId,
        name: slotName,
        ownerId: userId,
        locationId: locationId,
      );

      await newSlotRef.set(newSlot.toMap());
      _logger.i("Added parking slot $slotName ($newSlotId) for user $userId.");
    } catch (e) {
      _logger.e("Error adding parking slot: $e");
      rethrow;
    }
  }

  Future<void> updateParkingSlot({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
    required String newName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(slotId)
          .update({'name': newName});
      _logger
          .i("Updated parking slot $slotId to name $newName for user $userId.");
    } catch (e) {
      _logger.e("Error updating parking slot: $e");
      rethrow;
    }
  }

  Future<void> deleteParkingSlot({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(slotId)
          .delete();
      _logger.i("Deleted parking slot $slotId for user $userId.");
    } catch (e) {
      _logger.e("Error deleting parking slot: $e");
      rethrow;
    }
  }

  // NOVA METODA: Dohvaća ParkingRequest koji je dodijelio određeno mjesto u zadanom vremenskom okviru
  Future<ParkingRequest?> getAssignmentDetails({
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
    required DateTime desiredStartDateTime,
    required DateTime desiredEndDateTime,
  }) async {
    try {
      // Ovdje koristimo kolekciju 'parking_requests' (prema vašem kodu u parking_schedule_service.dart)
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .where('assignedSlots', arrayContains: slotId)
          .where('status', whereIn: ['approved', 'completed']).get();

      for (var doc in snapshot.docs) {
        ParkingRequest request =
            ParkingRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id);

        DateTime requestStart = DateTime(
          request.startDate.year,
          request.startDate.month,
          request.startDate.day,
          int.parse(request.startTime.split(':')[0]),
          int.parse(request.startTime.split(':')[1]),
        );

        DateTime requestEnd = DateTime(
          request.endDate.year,
          request.endDate.month,
          request.endDate.day,
          int.parse(request.endTime.split(':')[0]),
          int.parse(request.endTime.split(':')[1]),
        );

        // Provjera preklapanja
        bool overlaps = desiredStartDateTime.isBefore(requestEnd) &&
            desiredEndDateTime.isAfter(requestStart);

        if (overlaps) {
          return request;
        }
      }

      return null;
    } catch (e) {
      _logger.e("Error fetching assignment details: $e");
      rethrow;
    }
  }
}
