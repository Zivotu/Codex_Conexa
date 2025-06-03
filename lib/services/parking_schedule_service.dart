// lib/services/parking_schedule_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import '../models/parking_request.dart';
import '../models/parking_slot.dart';
import 'localization_service.dart'; // Pretpostavljamo da ova klasa ima statičku instancu

final Logger _logger = Logger();

class ParkingScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ParkingRequest>> getPendingRequests({
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => ParkingRequest.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingPendingParkingRequests') ?? 'Error fetching pending parking requests'}: $e");
      rethrow;
    }
  }

  Future<List<ParkingRequest>> getActivePendingRequests({
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .where('status', isEqualTo: 'pending')
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
          .get();

      return snapshot.docs
          .map((doc) => ParkingRequest.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingActivePendingParkingRequests') ?? 'Error fetching active pending parking requests'}: $e");
      rethrow;
    }
  }

  Future<List<ParkingRequest>> getHistoricalPendingRequests({
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .where('status', isEqualTo: 'pending')
          .where('endDate', isLessThan: Timestamp.now())
          .get();

      return snapshot.docs
          .map((doc) => ParkingRequest.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingHistoricalPendingParkingRequests') ?? 'Error fetching historical pending parking requests'}: $e");
      rethrow;
    }
  }

  Future<List<ParkingSlot>> getAvailableUserParkingSlots({
    required String countryId,
    required String cityId,
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
    required String requestStartTime,
    required String requestEndTime,
    required String userId,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
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

      List<ParkingSlot> availableSlots = [];

      for (var doc in snapshot.docs) {
        final slotData = doc.data() as Map<String, dynamic>;
        ParkingSlot slot = ParkingSlot.fromMap(slotData, doc.id);

        bool isAvailable = await isSlotAvailable(
          countryId: countryId,
          cityId: cityId,
          locationId: locationId,
          userId: userId,
          slotId: slot.id,
          startDate: startDate,
          endDate: endDate,
          startTime: requestStartTime,
          endTime: requestEndTime,
        );

        if (isAvailable) {
          availableSlots.add(slot);
        }
      }

      return availableSlots;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorGettingUserAvailableParkingSlots') ?? 'Error getting user available parking slots'}: $e");
      rethrow;
    }
  }

  Future<bool> isSlotAvailable({
    required String countryId,
    required String cityId,
    required String locationId,
    required String userId,
    required String slotId,
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    bool checkAssignedRequests = false,
  }) async {
    try {
      final reservationsRef = _firestore
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
          .collection('reservations');

      final snapshot = await reservationsRef.get();

      DateTime requestedStart = _combineDateAndTime(startDate, startTime);
      DateTime requestedEnd = _combineDateAndTime(endDate, endTime);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime existingStart = (data['startDate'] as Timestamp).toDate();
        String existingStartTime = data['startTime'];
        DateTime existingEnd = (data['endDate'] as Timestamp).toDate();
        String existingEndTime = data['endTime'];

        DateTime existingStartDateTime =
            _combineDateAndTime(existingStart, existingStartTime);
        DateTime existingEndDateTime =
            _combineDateAndTime(existingEnd, existingEndTime);

        if (_isOverlapping(requestedStart, requestedEnd, existingStartDateTime,
            existingEndDateTime)) {
          return false;
        }
      }

      if (checkAssignedRequests) {
        final assignedRequestsRef = _firestore
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
            .collection('assigned_requests');

        final assignedSnapshot = await assignedRequestsRef.get();

        for (var doc in assignedSnapshot.docs) {
          final data = doc.data();
          DateTime existingStart = (data['startDate'] as Timestamp).toDate();
          String existingStartTime = data['startTime'];
          DateTime existingEnd = (data['endDate'] as Timestamp).toDate();
          String existingEndTime = data['endTime'];

          DateTime existingStartDateTime =
              _combineDateAndTime(existingStart, existingStartTime);
          DateTime existingEndDateTime =
              _combineDateAndTime(existingEnd, existingEndTime);

          if (_isOverlapping(requestedStart, requestedEnd,
              existingStartDateTime, existingEndDateTime)) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorCheckingSlotAvailability') ?? 'Error checking slot availability'}: $e");
      rethrow;
    }
  }

  bool _isOverlapping(
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  DateTime _combineDateAndTime(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> addReservationToSlot({
    required String countryId,
    required String cityId,
    required String locationId,
    required String userId,
    required String slotId,
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required String assignedTo,
  }) async {
    try {
      bool isAvailable = await isSlotAvailable(
        countryId: countryId,
        cityId: cityId,
        locationId: locationId,
        userId: userId,
        slotId: slotId,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
      );

      if (!isAvailable) {
        throw Exception(
            LocalizationService.instance.translate('slotNotAvailable') ??
                'Parking slot is not available for the selected time.');
      }

      final slotDocRef = _firestore
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
          .collection('reservations');

      await slotDocRef.add({
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'startTime': startTime,
        'endTime': endTime,
        'assignedTo': assignedTo,
      });

      _logger.i(
          "${LocalizationService.instance.translate('reservationAdded').replaceAll('{slotId}', slotId) ?? 'Reservation added for slot'} $slotId.");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorAddingReservation') ?? 'Error adding reservation to slot'}: $e");
      rethrow;
    }
  }

  Future<void> updateParkingRequestStatus({
    required String countryId,
    required String cityId,
    required String locationId,
    required String requestId,
    required String newStatus,
    required String message,
    String? approvedBy,
    DateTime? assignedAt,
  }) async {
    try {
      final requestRef = _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId);

      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'message': message,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approvedBy != null) {
        updateData['approvedBy'] = approvedBy;
      }
      if (assignedAt != null) {
        updateData['assignedAt'] = Timestamp.fromDate(assignedAt);
      }

      await requestRef.update(updateData);

      _logger.i(
          "${LocalizationService.instance.translate('requestStatusUpdated') ?? 'Request status updated'}: $requestId");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorUpdatingParkingRequestStatus') ?? 'Error updating request status'}: $e");
      rethrow;
    }
  }

  Future<void> deleteParkingRequest({
    required String countryId,
    required String cityId,
    required String locationId,
    required String requestId,
  }) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId)
          .delete();

      _logger.i(
          "${LocalizationService.instance.translate('parkingRequestDeleted') ?? 'Parking request deleted'}: $requestId");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorDeletingParkingRequest') ?? 'Error deleting parking request'}: $e");
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
      QuerySnapshot snapshot = await _firestore
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

      List<ParkingSlot> slots = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        slots.add(ParkingSlot.fromMap(data, doc.id));
      }
      return slots;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorGettingUserParkingSlots') ?? 'Error getting user parking slots'}: $e");
      rethrow;
    }
  }

  Future<List<String>> getAssignedSpots({
    required String countryId,
    required String cityId,
    required String locationId,
    required String requestId,
  }) async {
    try {
      final assignedSpotsRef = _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId);

      final snapshot = await assignedSpotsRef.get();
      final data = snapshot.data();

      if (data != null && data['assignedSlots'] != null) {
        return List<String>.from(data['assignedSlots']);
      }

      return [];
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingAssignedSpots') ?? 'Error fetching assigned spots'}: $e");
      return [];
    }
  }

  Future<String> getSlotName({
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
  }) async {
    try {
      QuerySnapshot parkingUsersSnapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .get();

      for (var userDoc in parkingUsersSnapshot.docs) {
        DocumentSnapshot slotSnapshot = await userDoc.reference
            .collection('parkingSlots')
            .doc(slotId)
            .get();

        if (slotSnapshot.exists) {
          var slotData = slotSnapshot.data() as Map<String, dynamic>;
          return slotData['name'] ??
              (LocalizationService.instance.translate('unknownSlot') ??
                  'Unknown slot');
        }
      }

      return LocalizationService.instance.translate('unknownSlot') ??
          'Unknown slot';
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorGettingSlotName') ?? 'Error getting slot name'}: $e");
      return LocalizationService.instance.translate('unknownSlot') ??
          'Unknown slot';
    }
  }

  Future<Map<String, dynamic>?> getSlotOwnerData({
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
  }) async {
    try {
      QuerySnapshot parkingUsersSnapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .get();

      for (var userDoc in parkingUsersSnapshot.docs) {
        DocumentSnapshot slotSnapshot = await userDoc.reference
            .collection('parkingSlots')
            .doc(slotId)
            .get();

        if (slotSnapshot.exists) {
          var slotData = slotSnapshot.data() as Map<String, dynamic>;
          String ownerId = slotData['ownerId'] ?? '';
          if (ownerId.isNotEmpty) {
            DocumentSnapshot userSnapshot =
                await _firestore.collection('users').doc(ownerId).get();
            return userSnapshot.data() as Map<String, dynamic>?;
          }
        }
      }

      return null;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorGettingSlotOwnerData') ?? 'Error getting slot owner data'}: $e");
      return null;
    }
  }

  Stream<List<ParkingRequest>> getParkingRequests({
    required String countryId,
    required String cityId,
    required String locationId,
  }) {
    return _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('parking_requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ParkingRequest.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<List<String>> getUserAssignedSpots({
    required String countryId,
    required String cityId,
    required String locationId,
    required String requestId,
    required String currentUserId,
  }) async {
    try {
      final requestRef = _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId);

      final snapshot = await requestRef.get();
      final data = snapshot.data();

      if (data != null && data['assignedSlots'] != null) {
        List<String> assignedSlots = List<String>.from(data['assignedSlots']);
        List<String> userAssignedSlots = [];

        for (String slotId in assignedSlots) {
          final assignedRequestRef = _firestore
              .collection('countries')
              .doc(countryId)
              .collection('cities')
              .doc(cityId)
              .collection('locations')
              .doc(locationId)
              .collection('parking_slots')
              .doc(slotId)
              .collection('assigned_requests')
              .doc(requestId);

          final assignedRequestSnapshot = await assignedRequestRef.get();
          final assignedRequestData = assignedRequestSnapshot.data();

          if (assignedRequestData != null &&
              assignedRequestData['assignedBy'] == currentUserId) {
            userAssignedSlots.add(slotId);
          }
        }

        return userAssignedSlots;
      }

      return [];
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingUserAssignedSpots') ?? 'Error fetching user-assigned spots'}: $e");
      return [];
    }
  }

  Future<String> createParkingRequest({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required int numberOfSpots,
    required DateTime startDate,
    required String startTime,
    required DateTime endDate,
    required String endTime,
    String? message,
  }) async {
    try {
      String requestId = const Uuid().v4();
      ParkingRequest request = ParkingRequest(
        requestId: requestId,
        requesterId: userId,
        numberOfSpots: numberOfSpots,
        startDate: startDate,
        startTime: startTime,
        endDate: endDate,
        endTime: endTime,
        status: 'pending',
        message: message ?? '',
        countryId: countryId,
        cityId: cityId,
        locationId: locationId,
      );

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId)
          .set(request.toMap());

      _logger.i(
          "${LocalizationService.instance.translate('parkingRequestCreated').replaceAll('{requestId}', requestId) ?? 'Parking request created:'} $requestId");
      return requestId;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorCreatingParkingRequest') ?? 'Error creating parking request'}: $e");
      rethrow;
    }
  }

  Future<ParkingRequest?> getAssignmentDetails({
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
    required DateTime desiredStartDateTime,
    required DateTime desiredEndDateTime,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
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

        bool overlaps = desiredStartDateTime.isBefore(requestEnd) &&
            desiredEndDateTime.isAfter(requestStart);

        if (overlaps) {
          return request;
        }
      }

      return null;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingAssignmentDetails') ?? 'Error fetching assignment details'}: $e");
      rethrow;
    }
  }

  Future<ParkingRequest?> getAssignedRequestForSlotOnDate({
    required String countryId,
    required String cityId,
    required String locationId,
    required String slotId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final assignedRequestsRef = _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parkingSlots')
          .doc(slotId)
          .collection('assigned_requests');

      final snapshot = await assignedRequestsRef.get();

      DateTime requestedDateTime = _combineDateAndTime(date, '00:00');
      DateTime requestedEndDateTime = _combineDateAndTime(date, '23:59');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime existingStart = (data['startDate'] as Timestamp).toDate();
        String existingStartTime = data['startTime'];
        DateTime existingEnd = (data['endDate'] as Timestamp).toDate();
        String existingEndTime = data['endTime'];

        DateTime existingStartDateTime =
            _combineDateAndTime(existingStart, existingStartTime);
        DateTime existingEndDateTime =
            _combineDateAndTime(existingEnd, existingEndTime);

        if (_isOverlapping(requestedDateTime, requestedEndDateTime,
            existingStartDateTime, existingEndDateTime)) {
          return ParkingRequest.fromMap(doc.data(), doc.id);
        }
      }

      return null;
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorFetchingAssignedRequestForSlot') ?? 'Error fetching assigned request for slot'} $slotId ${LocalizationService.instance.translate('onDate') ?? 'on date'} $date: $e");
      return null;
    }
  }

  Future<void> defineVacation({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String parkingSlotId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final vacMap = {
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      };

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(parkingSlotId)
          .update({'vacation': vacMap});

      _logger.i(
          "${LocalizationService.instance.translate('vacationDefined') ?? 'Vacation defined/updated for'} $parkingSlotId.");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorDefiningVacation') ?? 'Error defining vacation'}: $e");
      rethrow;
    }
  }

  Future<void> removeVacation({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String parkingSlotId,
  }) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(parkingSlotId)
          .update({'vacation': FieldValue.delete()});
      _logger.i(
          "${LocalizationService.instance.translate('vacationRemoved') ?? 'Vacation removed for'} $parkingSlotId.");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorRemovingVacation') ?? 'Error removing vacation'}: $e");
      rethrow;
    }
  }

  Future<void> definePermanentAvailability({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String parkingSlotId,
    required bool isEnabled,
    required List<String> days,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      String start = _formatTimeOfDay(startTime);
      String end = _formatTimeOfDay(endTime);

      final permMap = {
        'isEnabled': isEnabled,
        'days': days,
        'startTime': start,
        'endTime': end,
      };

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(parkingSlotId)
          .update({'permanentAvailability': permMap});

      _logger.i(
          "${LocalizationService.instance.translate('permanentAvailabilityDefined') ?? 'Permanent availability defined/updated for'} $parkingSlotId.");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorDefiningPermanentAvailability') ?? 'Error defining permanent availability'}: $e");
      rethrow;
    }
  }

  Future<void> assignMultipleSlots({
    required String countryId,
    required String cityId,
    required String locationId,
    required String requestId,
    required List<String> selectedSlotIds,
    required String assignedBy,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception(
            LocalizationService.instance.translate('requestNotFound') ??
                "Request not found.");
      }

      final requestData = requestDoc.data()!;
      final remainingSpots = requestData['numberOfSpots'] as int;
      final alreadyAssigned = requestData['assignedSlots'] != null
          ? List<String>.from(requestData['assignedSlots'])
          : <String>[];

      int assignedCount = selectedSlotIds.length;
      final newAssignedSlots = [...alreadyAssigned, ...selectedSlotIds];
      final remainingAfterAssignment = remainingSpots - assignedCount;

      Map<String, dynamic> updateData = {
        'numberOfSpots': remainingAfterAssignment,
        'assignedSlots': newAssignedSlots,
      };

      if (remainingAfterAssignment == 0) {
        updateData['status'] = 'approved';
        updateData['message'] =
            LocalizationService.instance.translate('requestFullyApproved') ??
                'Your request has been fully approved.';
      } else {
        updateData['status'] = 'pending';
        updateData['message'] = (LocalizationService.instance
                    .translate('requestPartiallyApproved') ??
                'Your request is partially approved, remaining to assign: {remaining}')
            .replaceAll('{remaining}', remainingAfterAssignment.toString());
      }

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking_requests')
          .doc(requestId)
          .update(updateData);

      QuerySnapshot parkingUsersSnapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .get();

      DateTime startDate = (requestData['startDate'] as Timestamp).toDate();
      DateTime endDate = (requestData['endDate'] as Timestamp).toDate();
      String reqStartTime = requestData['startTime'];
      String reqEndTime = requestData['endTime'];
      String requesterId = requestData['requesterId'];

      for (final slotId in selectedSlotIds) {
        String ownerId = '';
        for (var userDoc in parkingUsersSnapshot.docs) {
          final slotDoc = await userDoc.reference
              .collection('parkingSlots')
              .doc(slotId)
              .get();
          if (slotDoc.exists) {
            ownerId = userDoc.id;
            break;
          }
        }

        if (ownerId.isEmpty) {
          _logger.w(
              "${LocalizationService.instance.translate('ownerNotFoundForSlot') ?? 'Owner for slot'} $slotId ${LocalizationService.instance.translate('notFound') ?? 'not found'}. ${LocalizationService.instance.translate('reservationNotAdded') ?? 'Reservation will not be added.'}");
          continue;
        }

        await _firestore
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('parking')
            .doc(ownerId)
            .collection('parkingSlots')
            .doc(slotId)
            .collection('assigned_requests')
            .doc(requestId)
            .set({
          'requestId': requestId,
          'assignedBy': assignedBy,
          'assignedAt': Timestamp.now(),
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'startTime': reqStartTime,
          'endTime': reqEndTime,
          'requesterId': requesterId,
        });
      }

      _logger.i(LocalizationService.instance
              .translate('multipleSlotsAssigned')
              .replaceAll('{assigned}', selectedSlotIds.length.toString())
              .replaceAll('{remaining}', remainingAfterAssignment.toString()) ??
          'Request updated');
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorAssigningSlots') ?? 'Error assigning slots'}: $e");
      rethrow;
    }
  }

  Future<void> removePermanentAvailability({
    required String userId,
    required String countryId,
    required String cityId,
    required String locationId,
    required String parkingSlotId,
  }) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('parking')
          .doc(userId)
          .collection('parkingSlots')
          .doc(parkingSlotId)
          .update({
        'permanentAvailability': FieldValue.delete(),
      });
      _logger.i(
          "${LocalizationService.instance.translate('permanentAvailabilityRemoved') ?? 'Permanent availability removed for'} $parkingSlotId.");
    } catch (e) {
      _logger.e(
          "${LocalizationService.instance.translate('errorRemovingPermanentAvailability') ?? 'Error removing permanent availability'}: $e");
      rethrow;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
