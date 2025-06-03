import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Funkcija za praćenje novih biltena u posljednjih 12 sati
Future<int> getNewBulletinsCount(String locationId, String username) async {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('locations/$locationId/bulletin_board')
      .where('deleted', isEqualTo: false)
      .where('createdAt',
          isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 12))))
      .get();

  return querySnapshot.docs.length;
}

String formatDate(DateTime date) {
  return DateFormat('dd.MM.yyyy. - HH:mm').format(date);
}
