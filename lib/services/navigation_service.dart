import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../screens/blog_screen_wrapper.dart';

class NavigationService {
  final Logger logger = Logger();

  void navigateToCategory(BuildContext context,
      {required String route,
      required String categoryField,
      required String username,
      required String countryId,
      required String cityId,
      required String locationId}) async {
    await resetNewPostsCount(
        username, categoryField, countryId, cityId, locationId);
    await trackCategoryVisit(categoryField, countryId, cityId, locationId);
    if (context.mounted) {
      Navigator.pushNamed(context, route, arguments: {
        'username': username,
        'countryId': countryId,
        'cityId': cityId,
        'locationId': locationId,
      });
    }
  }

  void navigateToBlogScreen(BuildContext context,
      {required String username,
      required String countryId,
      required String cityId,
      required String locationId}) async {
    await resetNewPostsCount(username, 'blogs', countryId, cityId,
        locationId); // Adjust category field as necessary
    await trackCategoryVisit('blogs', countryId, cityId,
        locationId); // Adjust category field as necessary
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BlogScreenWrapper(),
      ),
    );
  }

  Future<void> resetNewPostsCount(String username, String categoryField,
      String countryId, String cityId, String locationId) async {
    // Provjera da li su svi parametri ne-prazni
    if (username.isEmpty ||
        categoryField.isEmpty ||
        countryId.isEmpty ||
        cityId.isEmpty ||
        locationId.isEmpty) {
      logger.w('Jedan ili više parametara su prazni. Preskačem resetiranje.');
      return; // Preskačemo ostatak koda
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('users')
          .doc(username)
          .get();

      if (userDoc.exists) {
        await userDoc.reference.update({
          'categoryVisits.$categoryField': FieldValue.serverTimestamp(),
          'newPostsCount.$categoryField': 0,
        });
        logger.d('New posts count reset for $categoryField');
      } else {
        logger.w('User document does not exist.');
      }
    } catch (e) {
      logger.e('Error resetting new posts count: $e');
    }
  }

  Future<void> trackCategoryVisit(String category, String countryId,
      String cityId, String locationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDocRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('users')
          .doc(user.uid);

      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        await userDocRef.set({
          'categoryVisitCounts': {category: 0},
        });
      }

      final userDocData = userDoc.data() ?? {};
      final categoryVisitCounts =
          userDocData['categoryVisitCounts'] as Map<String, dynamic>? ?? {};

      if (!categoryVisitCounts.containsKey(category)) {
        categoryVisitCounts[category] = 0;
      }

      await userDocRef.update({
        'categoryVisitCounts.$category': FieldValue.increment(1),
      });
    }
  }
}
