import 'package:cloud_firestore/cloud_firestore.dart';

class LocationActivationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateAllLocationActivation({
    required String locationId,
    required String countryId,
    required String cityId,
    required String userId,
    required String activationType,
    required DateTime activeUntil,
    String? attachedPaymentId,
    bool trialPeriod = false,
  }) async {
    WriteBatch batch = _firestore.batch();

    // Ažuriramo glavnu kolekciju 'locations'
    DocumentReference mainLocationRef =
        _firestore.collection('locations').doc(locationId);
    batch.set(
        mainLocationRef,
        {
          'activationType': activationType,
          'activeUntil': Timestamp.fromDate(activeUntil),
          'attachedPaymentId': attachedPaymentId,
          'trialPeriod': trialPeriod,
        },
        SetOptions(merge: true));

    // Ažuriramo kolekciju countries/cities/locations
    DocumentReference countryCityLocationRef = _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId);
    batch.set(
        countryCityLocationRef,
        {
          'activationType': activationType,
          'activeUntil': Timestamp.fromDate(activeUntil),
          'attachedPaymentId': attachedPaymentId,
          'trialPeriod': trialPeriod,
        },
        SetOptions(merge: true));

    // Ažuriramo kolekciju 'user_locations'
    DocumentReference userLocationRef = _firestore
        .collection('user_locations')
        .doc(userId)
        .collection('locations')
        .doc(locationId);
    batch.set(
        userLocationRef,
        {
          'activationType': activationType,
          'activeUntil': Timestamp.fromDate(activeUntil),
          'attachedPaymentId': attachedPaymentId,
          'trialPeriod': trialPeriod,
        },
        SetOptions(merge: true));

    // Napomena: Ne ažuriramo 'location_users' jer tamo nemamo sigurno kreiran dokument.

    await batch.commit();
  }
}
