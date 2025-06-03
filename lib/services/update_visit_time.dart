import 'package:cloud_firestore/cloud_firestore.dart';

void updateVisitTime(String userId, String categoryId) {
  FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('categories')
      .doc(categoryId)
      .set({
    'lastVisited': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
