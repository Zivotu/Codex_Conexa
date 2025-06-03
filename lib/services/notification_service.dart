import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../services/localization_service.dart';

final Logger _logger = Logger();

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getNewChatMessagesCount(
      String countryId, String cityId, String locationId) {
    return _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('chats')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getNewOfficialNoticesCount(
      String countryId, String cityId, String locationId) {
    return _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('official_notices')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getNewBulletinBoardPostsCount(
      String countryId, String cityId, String locationId) {
    return _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('bulletin_board')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getNewDocumentsCount(
      String countryId, String cityId, String locationId) {
    return _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('documents')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Metoda za slanje notifikacije nakon odobravanja parking zahtjeva
  /// Napomena: Slanje push notifikacija iz klijenta nije podržano. Preporučuje se korištenje Firebase Cloud Functions za slanje notifikacija.
  Future<void> sendParkingRequestApprovedNotification({
    required String requestId,
    required String approvedBy,
    required int spotsApproved,
    required int totalSpots,
  }) async {
    try {
      QuerySnapshot requestSnapshot = await _firestore
          .collectionGroup('parking_requests')
          .where('requestId', isEqualTo: requestId)
          .get();

      if (requestSnapshot.docs.isEmpty) {
        throw Exception(
            LocalizationService.instance.translate('parkingRequestNotFound') ??
                "Parking request $requestId does not exist.");
      }

      Map<String, dynamic> requestData =
          requestSnapshot.docs.first.data() as Map<String, dynamic>;
      String requesterId = requestData['requesterId'];

      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(requesterId).get();

      if (!userSnapshot.exists) {
        throw Exception(
            LocalizationService.instance.translate('userNotFound') ??
                "User $requesterId does not exist.");
      }

      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      String? fcmToken = userData['fcmToken'];

      if (fcmToken == null) {
        _logger.w(LocalizationService.instance.translate('userHasNoFCMToken') ??
            "User has no FCM token: $requesterId");
        return;
      }

      String title =
          LocalizationService.instance.translate('parkingRequestTitle') ??
              'Parking Request';
      String body;
      if (spotsApproved < totalSpots) {
        body = LocalizationService.instance
                .translate('parkingRequestPartiallyApproved') ??
            'Your request for $totalSpots parking spaces was partially approved. Approved: $spotsApproved/$totalSpots.';
      } else {
        body = LocalizationService.instance
                .translate('parkingRequestFullyApproved') ??
            'Your request for $totalSpots parking spaces was fully approved.';
      }

      // Ovdje možete pozvati cloud function koja će poslati notifikaciju

      _logger.i(
          "Push notification should be sent to user $requesterId with FCM token $fcmToken");
    } catch (e) {
      _logger.e(
          LocalizationService.instance.translate('errorSendingNotification') ??
              "Error sending notification: $e");
      rethrow;
    }
  }

  /// Metoda za slanje push notifikacije putem Firebase Cloud Functions
  /// Ovo je placeholder i treba ga implementirati u Firebase Cloud Functions
  /*
  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    // Implementacija bi trebala koristiti Firebase Cloud Functions ili server-side SDK
  }
  */
}
