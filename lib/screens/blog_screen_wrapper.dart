import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'blog_screen.dart';
import '../services/localization_service.dart';

final Logger _logger = Logger();

class BlogScreenWrapper extends StatelessWidget {
  const BlogScreenWrapper({super.key});

  static Map<String, dynamic>? _cachedUserData;

  Future<Map<String, dynamic>> fetchUserData() async {
    if (_cachedUserData != null) {
      _logger.d("Using cached user data.");
      return _cachedUserData!;
    }

    _logger.d("Fetching user data from Firestore");
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid;

      try {
        final userMainDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userMainDoc.exists) {
          final mainData = userMainDoc.data()!;
          final countryId = mainData['geoCountryId'];
          final cityId = mainData['geoCityId'];
          final locationId = mainData['geoNeighborhoodId'];

          final userLocationDoc = await FirebaseFirestore.instance
              .collection('user_locations')
              .doc(userId)
              .collection('locations')
              .doc(locationId)
              .get();

          if (userLocationDoc.exists) {
            final userData = userLocationDoc.data()!;
            final bool locationAdmin = userData['locationAdmin'] ?? false;
            _logger.d("Fetched locationAdmin: $locationAdmin");

            _cachedUserData = {
              'username': user.email!,
              'countryId': countryId,
              'cityId': cityId,
              'locationId': locationId,
              'locationAdmin': locationAdmin,
            };

            return _cachedUserData!;
          } else {
            _logger.e("User document does not exist in user_locations.");
          }
        } else {
          _logger.e("Main user document does not exist.");
        }
      } catch (e) {
        _logger.e("Error fetching user data: $e");
      }
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text(localization.translate('error_fetching_data') ??
                  'Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(localization.translate('no_user_data') ??
                  'No user data available'));
        } else {
          final data = snapshot.data!;
          _logger.d("Passing user data to BlogScreen: $data");

          return BlogScreen(
            username: data['username'],
            countryId: data['countryId'],
            cityId: data['cityId'],
            locationId: data['locationId'],
          );
        }
      },
    );
  }
}
