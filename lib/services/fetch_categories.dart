import 'package:cloud_firestore/cloud_firestore.dart';

Stream<List<Map<String, dynamic>>> fetchCategories(String userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('categories')
      .orderBy('lastVisited', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList());
}
