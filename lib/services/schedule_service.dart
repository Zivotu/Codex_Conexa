// lib/services/schedule_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Dohvaća raspored za određenu lokaciju
  Future<Map<String, dynamic>?> getSchedule(
      String countryId, String cityId, String locationId) async {
    try {
      final doc = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .get();

      if (doc.exists) {
        _logger.d("Fetched schedule for location $locationId: ${doc.data()}");
        return doc.data();
      }
      _logger.w("Schedule does not exist for location $locationId.");
      return null;
    } catch (e) {
      _logger.e("Failed to get schedule for location $locationId: $e");
      throw Exception('Failed to get schedule: $e');
    }
  }

  /// Kreira novi raspored
  Future<void> createSchedule(
      String countryId,
      String cityId,
      String locationId,
      DateTime startDate,
      DateTime endDate,
      List<String> userIds,
      String creatorId) async {
    // Dodan parametar creatorId
    try {
      Map<String, dynamic> assignments = {};
      DateTime currentDate = startDate;
      int userIndex = 0;

      while (!currentDate.isAfter(endDate)) {
        String dateStr = currentDate.toIso8601String().split('T')[0];
        assignments[dateStr] = userIds[userIndex % userIds.length];
        currentDate = currentDate.add(const Duration(days: 1));
        userIndex++;
      }

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .set({
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'assignments': assignments,
        'creatorId': creatorId, // Pohrana ID kreatora
      });
      _logger.i("Schedule created for location $locationId: $assignments");
    } catch (e) {
      _logger.e("Failed to create schedule for location $locationId: $e");
      throw Exception('Failed to create schedule: $e');
    }
  }

  /// Ažurira dodjelu za određeni dan
  Future<void> updateAssignment(String countryId, String cityId,
      String locationId, String date, String userId) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .update({
        'assignments.$date': userId,
      });
      _logger
          .i("Assignment updated for location $locationId on $date: $userId");
    } catch (e) {
      _logger.e(
          "Failed to update assignment for location $locationId on $date: $e");
      throw Exception('Failed to update assignment: $e');
    }
  }

  /// Bilježi zahtjev za uklanjanje korisnika za određeni datum
  Future<void> requestRemoval(String countryId, String cityId,
      String locationId, String date, String userId) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .collection('removal_requests')
          .doc(date)
          .set({
        'userId': userId,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'requested' // Možemo označiti i status zahtjeva
      }, SetOptions(merge: true));

      _logger.i(
          "Removal request logged for location $locationId on $date by user $userId.");
    } catch (e) {
      _logger.e(
          "Failed to log removal request for location $locationId on $date: $e");
      throw Exception('Failed to log removal request: $e');
    }
  }

  /// Briše zahtjev za uklanjanje korisnika za određeni datum
  Future<void> deleteRemovalRequest(
      String countryId, String cityId, String locationId, String date) async {
    try {
      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .collection('removal_requests')
          .doc(date)
          .delete();
      _logger.i("Removal request deleted for location $locationId on $date.");
    } catch (e) {
      _logger.e(
          "Failed to delete removal request for location $locationId on $date: $e");
      throw Exception('Failed to delete removal request: $e');
    }
  }

  /// Dohvaća sve zahtjeve za uklanjanje za određenu lokaciju
  Future<Map<String, dynamic>?> getRemovalRequests(
      String countryId, String cityId, String locationId) async {
    try {
      final querySnapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .collection('removal_requests')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        Map<String, dynamic> removalRequests = {};
        for (var doc in querySnapshot.docs) {
          removalRequests[doc.id] = doc.data();
        }
        _logger.d(
            "Fetched removal requests for location $locationId: $removalRequests");
        return removalRequests;
      }
      _logger.i("No removal requests found for location $locationId.");
      return null;
    } catch (e) {
      _logger.e("Failed to get removal requests for location $locationId: $e");
      throw Exception('Failed to get removal requests: $e');
    }
  }

  /// Briše raspored za određenu lokaciju
  Future<void> deleteSchedule(
      String countryId, String cityId, String locationId) async {
    try {
      // Prvo dohvatimo sve removal_requests kako bismo ih obrisali
      final removalRequestsSnapshot = await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .collection('removal_requests')
          .get();

      for (var doc in removalRequestsSnapshot.docs) {
        await doc.reference.delete();
      }

      await _firestore
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('snow_cleaning_schedules')
          .doc(locationId)
          .delete();
      _logger
          .i("Schedule and removal requests deleted for location $locationId.");
    } catch (e) {
      _logger.e("Failed to delete schedule for location $locationId: $e");
      throw Exception('Failed to delete schedule: $e');
    }
  }
}
