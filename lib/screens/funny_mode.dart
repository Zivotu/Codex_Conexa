// C:\Conexa_11f\lib\screens\funny_mode.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';
import 'dart:math';
import '../services/navigation_service.dart';
import 'package:get_it/get_it.dart';
import '../widgets/category_card.dart'; // Ensure this path is correct

class FunnyMode extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;

  const FunnyMode({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
  });

  @override
  _FunnyModeState createState() => _FunnyModeState();
}

class _FunnyModeState extends State<FunnyMode> {
  final Logger _logger = Logger();

  List<Map<String, dynamic>> randomAds = [];
  late Future<List<String>> _randomAdTitlesFuture;
  late Future<String> _wiseOwlSubtitleFuture;

  @override
  void initState() {
    super.initState();
    _fetchRandomAds();
    _randomAdTitlesFuture = _getRandomAdTitlesFuture();
    _wiseOwlSubtitleFuture = getNewDailySayingFuture();
  }

  // Dohvat nasumičnih oglasa iz Marketplace-a
  Future<void> _fetchRandomAds() async {
    try {
      final adQuery = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('ads')
          .where('ended', isEqualTo: false)
          .get();

      final ads = adQuery.docs.map((doc) => doc.data()).toList();

      if (ads.isNotEmpty) {
        ads.shuffle();
        setState(() {
          randomAds = ads.take(2).toList();
        });
      }
    } catch (e) {
      _logger.e('Error fetching ads: $e');
    }
  }

  Future<List<String>> _getRandomAdTitlesFuture() async {
    try {
      final adQuery = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('ads')
          .where('ended', isEqualTo: false)
          .get();

      final ads = adQuery.docs.map((doc) => doc['title'] as String?).toList();

      if (ads.isNotEmpty) {
        ads.shuffle();
        return ads.take(3).whereType<String>().toList();
      } else {
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching random ad titles: $e');
      return [];
    }
  }

  Future<String> getNewDailySayingFuture() async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(
          'gs://conexaproject-9660d.appspot.com/sayings/sayings.json');
      final String url = await ref.getDownloadURL();

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes);
        final List<dynamic> sayings =
            jsonDecode(utf8Body)['sayings'] as List<dynamic>;
        final int dayOfYear =
            DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
        return sayings[dayOfYear % sayings.length];
      } else {
        return 'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.';
      }
    } catch (e) {
      return 'Došlo je do pogreške. Pokušajte kasnije.';
    }
  }

  Stream<int> getNewPostsCountStream(String categoryField) {
    final DateTime last12Hours =
        DateTime.now().subtract(const Duration(hours: 12));
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection(categoryField)
        .where('createdAt', isGreaterThan: last12Hours)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    String title = ad['title'] ?? 'No Title';
    String? imageUrl = ad['imageUrl'];

    return CategoryCard(
      title: title,
      imagePath: imageUrl != null && imageUrl.isNotEmpty
          ? imageUrl
          : 'assets/images/feedback.png', // Koristi oglasnu sliku ili feedback.png
      route: '/ad_detail',
      username: widget.username,
      countryId: widget.countryId,
      cityId: widget.cityId,
      locationId: widget.locationId,
      newMessagesCount: 0,
      isActive: false,
      onTap: () {
        final navigationService = GetIt.I<NavigationService>();
        navigationService.navigateToCategory(
          context,
          route: '/ad_detail',
          categoryField: 'marketplace',
          username: widget.username,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigationService = GetIt.I<NavigationService>();

    // Definicija kategorija bez podnaslova
    final List<Map<String, dynamic>> categories = [
      {
        'title': 'Chat Room',
        'imagePath': 'assets/images/chat.png',
        'route': '/chat',
        'categoryField': 'chats',
      },
      {
        'title': 'Marketplace',
        'imagePath': 'assets/images/marketplace_1.jpg',
        'route': '/marketplace',
        'categoryField': 'marketplace',
      },
      {
        'title': 'Official Notices',
        'imagePath': 'assets/images/tenant.png',
        'route': '/blog',
        'categoryField': 'blogs',
      },
      {
        'title': 'Bulletin Board',
        'imagePath': 'assets/images/feedback.png', // Zadana slika
        'route': '/bulletin',
        'categoryField': 'bulletin_board',
      },
      {
        'title': 'Documents',
        'imagePath': 'assets/images/documents.png',
        'route': '/documents',
        'categoryField': 'documents',
      },
      {
        'title': 'Home Services',
        'imagePath': 'assets/images/blog.png',
        'route': '/service_requests',
        'categoryField': 'blogs',
      },
      {
        'title': 'I need a home repair service',
        'imagePath': 'assets/images/repair.png',
        'route': '/report',
        'categoryField': 'homeRepairService',
      },
      {
        'title': 'Games',
        'imagePath': 'assets/images/games.png',
        'route': '/games',
        'categoryField': 'games',
      },
      {
        'title': 'Settings',
        'imagePath': 'assets/images/settings.png',
        'route': '/settings',
        'categoryField': 'settings',
      },
      {
        'title': 'Security',
        'imagePath': 'assets/images/security.png',
        'route': '/security',
        'categoryField': 'security',
      },
      {
        'title': 'Alarm',
        'imagePath': 'assets/images/alarm.png',
        'route': '/alarm',
        'categoryField': 'alarm',
      },
      {
        'title': "Let's commute together",
        'imagePath': 'assets/images/notifications.png',
        'route': '/notifications',
        'categoryField': 'commuteTogether',
      },
      {
        'title': "Comments & Suggestions",
        'imagePath': 'assets/images/comments.png',
        'route': '/voxpopuli',
        'categoryField': 'voxpopuli',
      },
      {
        'title': 'Parking Zajednica',
        'imagePath': 'assets/images/parking.png',
        'route': '/parking_community',
        'categoryField': 'parking_community',
      },
      {
        'title': 'Čišćenje snijega',
        'imagePath': 'assets/images/snow.png',
        'route': '/snow_cleaning',
        'categoryField': 'snow_cleaning',
      },
      {
        'title': "Wise Owl",
        'imagePath': 'assets/images/owl_2.jpg',
        'route': '/wise_owl',
        'categoryField': 'wiseOwl',
      },
    ];

    // Kreiranje kopije kategorija za prikaz
    final List<Map<String, dynamic>> displayCategories = List.from(categories);

    // Umetanje nasumičnih oglasa na nasumične pozicije
    if (randomAds.isNotEmpty) {
      Random rnd = Random();
      for (var ad in randomAds) {
        int insertPosition = rnd.nextInt(displayCategories.length + 1);
        displayCategories.insert(insertPosition, {
          'title': ad['title'] ?? 'No Title',
          'imagePath': ad['imageUrl'] ?? 'assets/images/feedback.png',
          'route': '/ad_detail',
          'categoryField': 'marketplace',
          'isAd': true, // Oznaka da je ovo oglas
        });
      }
    }

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final category = displayCategories[index];

          // Provjera je li element oglas ili kategorija
          bool isAd = category['isAd'] == true;

          if (isAd) {
            // Oglas
            return _buildAdCard(category);
          } else {
            // Kategorija
            return StreamBuilder<int>(
              stream: getNewPostsCountStream(category['categoryField']),
              builder: (context, snapshot) {
                int newMessagesCount = snapshot.data ?? 0;
                bool isActive = newMessagesCount > 0;

                return CategoryCard(
                  title: category['title'],
                  imagePath: category['imagePath'].isNotEmpty
                      ? category['imagePath']
                      : 'assets/images/feedback.png', // Zadana slika
                  route: category['route'],
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  newMessagesCount: newMessagesCount,
                  isActive: isActive,
                  onTap: () => navigationService.navigateToCategory(
                    context,
                    route: category['route'],
                    categoryField: category['categoryField'],
                    username: widget.username,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
