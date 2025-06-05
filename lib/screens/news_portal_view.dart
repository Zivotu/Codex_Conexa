import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Modeli i servisi
import '../models/blog_model.dart';
import '../models/bulletin.dart';
import '../models/chat_model.dart';
import '../models/parking_request.dart';
import '../models/ride_model.dart';

import '../services/localization_service.dart';
import '../services/location_service.dart';
import '../services/parking_schedule_service.dart';

// Detaljni ekrani
import '../local/screens/post_detail_screen.dart';
import '../viewmodels/ride_view_model.dart';
import 'blog_details_screen.dart';
import 'ad_detail_screen.dart';
import 'full_screen_bulletin.dart';
import 'document_preview_screen.dart';
import 'parking_community_screen.dart';
import '../commute_screens/commute_ride_detail_screen.dart';
import 'group_chat_page.dart';
import '../widgets/section_card.dart';

// Ekrani za navigaciju prema kategorijama
import '../local/screens/local_home_screen.dart'; // Postovi – očekuje username i locationAdmin
import 'blog_screen.dart'; // Službene obavijesti – očekuje username, countryId, cityId, locationId
import 'marketplace_screen.dart'; // Marketplace – očekuje username, countryId, cityId, locationId
import '../commute_screens/commute_rides_list_screen.dart'; // Commute – očekuje username, countryId, cityId, locationId
import '../commute_widgets/commute_preview_card.dart';
import 'games_screen.dart'; // Kviz – očekuje username, countryId, cityId, locationId
import 'construction_screen.dart'; // Buka (radovi) – očekuje username, countryId, cityId, locationId
import 'bulletin_board_screen.dart'; // Bulletin – očekuje username, countryId, cityId, locationId
// Documents – koristi se u DocumentsScreen

// Dodajemo RideViewModel
import 'news_portal/news_portal_sections.dart';

// Import DocumentsScreen (sada je navigacija u DocumentsScreen)
import 'documents_screen.dart';

class ProfileAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.radius,
  });

  Future<String> _fetchProfileUrl() async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      return data['profileImageUrl'] ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _fetchProfileUrl(),
      builder: (context, snapshot) {
        String url = snapshot.data ?? '';
        if (url.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: url.startsWith('http')
                ? NetworkImage(url)
                : AssetImage(url) as ImageProvider,
          );
        }
        return CircleAvatar(
          radius: radius,
          child: Icon(Icons.person, size: radius, color: Colors.grey),
        );
      },
    );
  }
}

class NewsPortalView extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;
  final bool locationAdmin;

  const NewsPortalView({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
    required this.locationAdmin,
  });

  @override
  _NewsPortalViewState createState() => _NewsPortalViewState();
}

class _NewsPortalViewState extends State<NewsPortalView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();

  // Geo-lokacija
  String _geoCountry = '';
  String _geoCity = '';
  String _geoNeighborhood = '';

  // Mudra sova
  String? _dailySaying;

  // Buka – radovi
  List<Map<String, dynamic>> _works = [];

  // Parking preview
  List<ParkingRequest> _parkingPreview = [];

  // Commute preview (vožnje)
  List<Ride> _commutePreview = [];

  // Dodan ScrollController za RefreshIndicator
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _determineUserLocation().then((_) {
      _readConstructionData();
      _fetchParkingPreview();
      _fetchCommutePreview();
    });
    _fetchDailySaying();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Funkcija koja se poziva prilikom povlačenja (pull-to-refresh)
  Future<void> _refreshData() async {
    await _determineUserLocation();
    await _readConstructionData();
    await _fetchParkingPreview();
    await _fetchCommutePreview();
    await _fetchDailySaying();
  }

  Future<void> _determineUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _geoCountry = widget.countryId;
        _geoCity = widget.cityId;
        _geoNeighborhood = widget.locationId;
      });
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _geoCountry = widget.countryId;
          _geoCity = widget.cityId;
          _geoNeighborhood = widget.locationId;
        });
        return;
      }
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final locationService = LocationService();
      final geoData = await locationService.getGeographicalData(
          position.latitude, position.longitude);
      setState(() {
        _geoCountry = geoData['country'] ?? widget.countryId;
        _geoCity = geoData['city'] ?? widget.cityId;
        _geoNeighborhood = geoData['neighborhood'] ?? widget.locationId;
      });
    } catch (e) {
      setState(() {
        _geoCountry = widget.countryId;
        _geoCity = widget.cityId;
        _geoNeighborhood = widget.locationId;
      });
    }
  }

  /// A modern section header based on ListTile.
  Widget _buildModernSectionHeader(
      IconData iconData, String title, VoidCallback onTap,
      {Color? headerColor}) {
    return ListTile(
      onTap: onTap,
      leading:
          Icon(iconData, size: 28, color: headerColor ?? Colors.blueAccent),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _formatTimeAgo(DateTime dateTime, LocalizationService loc) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) {
      return loc.translate('just_now') ?? 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${loc.translate('minutes_ago') ?? 'minutes ago'}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${loc.translate('hours_ago') ?? 'hours ago'}';
    }
    return '${diff.inDays} ${loc.translate('days_ago') ?? 'days ago'}';
  }

  Widget _buildImage(String? imageUrl,
      {double width = 80, double height = 80, BoxFit fit = BoxFit.cover}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            color: Colors.grey,
            child: const Icon(Icons.image, color: Colors.white),
          ),
        );
      } else {
        return Image.asset(imageUrl, width: width, height: height, fit: fit);
      }
    }
    return Image.asset('assets/images/tenant.png',
        width: width, height: height, fit: fit);
  }

  String _formatDateTime(DateTime date, String time) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} $time';
  }

  Future<List<Map<String, dynamic>>> _fetchLastPosts() async {
    const int desiredCount = 4;
    List<Map<String, dynamic>> allPosts = [];
    DateTime now = DateTime.now();
    String currentMonthYear =
        '${now.year}_${now.month.toString().padLeft(2, '0')}';

    QuerySnapshot currentSnapshot = await _firestore
        .collectionGroup('posts_$currentMonthYear')
        .where('localCountryId',
            isEqualTo: _geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
        .where('localCityId',
            isEqualTo: _geoCity.isNotEmpty ? _geoCity : widget.cityId)
        .orderBy('createdAt', descending: true)
        .limit(desiredCount)
        .get();

    for (var doc in currentSnapshot.docs) {
      allPosts.add({'postId': doc.id, ...doc.data() as Map<String, dynamic>});
    }

    if (allPosts.length < desiredCount) {
      DateTime previousMonthDate = now.month == 1
          ? DateTime(now.year - 1, 12, now.day)
          : DateTime(now.year, now.month - 1, now.day);
      String previousMonthYear =
          '${previousMonthDate.year}_${previousMonthDate.month.toString().padLeft(2, '0')}';

      QuerySnapshot previousSnapshot = await _firestore
          .collectionGroup('posts_$previousMonthYear')
          .where('localCountryId',
              isEqualTo:
                  _geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
          .where('localCityId',
              isEqualTo: _geoCity.isNotEmpty ? _geoCity : widget.cityId)
          .orderBy('createdAt', descending: true)
          .limit(desiredCount - allPosts.length)
          .get();

      for (var doc in previousSnapshot.docs) {
        allPosts.add({'postId': doc.id, ...doc.data() as Map<String, dynamic>});
      }
    }

    allPosts.sort((a, b) {
      Timestamp tsA = (a['createdAt'] is Timestamp)
          ? a['createdAt'] as Timestamp
          : Timestamp.now();
      Timestamp tsB = (b['createdAt'] is Timestamp)
          ? b['createdAt'] as Timestamp
          : Timestamp.now();
      return tsB.compareTo(tsA);
    });

    return allPosts;
  }

  Future<void> _fetchDailySaying() async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(
          'gs://conexaproject-9660d.appspot.com/sayings/sayings.json');
      final String url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body = utf8.decode(response.bodyBytes);
        final List<dynamic> sayings =
            jsonDecode(utf8Body)['sayings'] as List<dynamic>;
        final yearStart = DateTime(DateTime.now().year, 1, 1);
        final int dayOfYear = DateTime.now().difference(yearStart).inDays;
        setState(() {
          _dailySaying = sayings[dayOfYear % sayings.length];
        });
      } else {
        setState(() {
          _dailySaying =
              'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.';
        });
      }
    } catch (e) {
      setState(() {
        _dailySaying = 'Došlo je do pogreške. Pokušajte kasnije.';
      });
    }
  }

  Future<void> _readConstructionData() async {
    try {
      final collection = LocationService().getConstructionsCollection(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );
      QuerySnapshot querySnapshot = await collection.get();
      List<Map<String, dynamic>> works = [];
      DateTime today = DateTime.now();
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> work = doc.data() as Map<String, dynamic>;
        if (!work.containsKey('startDate') || !work.containsKey('endDate')) {
          continue;
        }
        DateTime endDate = DateTime.parse(work['endDate']);
        if (endDate.isBefore(DateTime(today.year, today.month, today.day))) {
          continue;
        }
        work['key'] = doc.id;
        works.add(work);
      }
      setState(() {
        _works = works;
      });
    } catch (error) {
      debugPrint('Error reading construction data: $error');
    }
  }

  Widget _buildMarketplaceSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.store,
      title: loc.translate('marketplace') ?? 'Tržnica',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarketplaceScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLastMarketplaceAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(height: 100, child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                loc.translate('error_loading_marketplace_ads') ??
                    'Error loading marketplace ads.',
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                  loc.translate('no_ads_available') ?? 'No ads available.'),
            );
          }
          final adsData = snapshot.data!;
          return Column(
            children:
                adsData.map((ad) => _buildMarketplaceCard(ad, loc)).toList(),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLastMarketplaceAds() async {
    const int limitAds = 4;
    final String countryId =
        _geoCountry.isNotEmpty ? _geoCountry : widget.countryId;
    final String cityId = _geoCity.isNotEmpty ? _geoCity : widget.cityId;

    QuerySnapshot snapshot = await _firestore
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('ads')
        .where('ended', isEqualTo: false)
        .where('endDate', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('endDate', descending: false)
        .limit(limitAds)
        .get();

    return snapshot.docs.map((doc) {
      return {'docId': doc.id, ...doc.data() as Map<String, dynamic>};
    }).toList();
  }

  Widget _buildMarketplaceCard(
      Map<String, dynamic> adData, LocalizationService loc) {
    final List<dynamic> adImages =
        adData['imageUrls'] ?? adData['images'] ?? [];
    String imageUrl = '';
    if (adImages.isNotEmpty && adImages[0] is String) {
      imageUrl = adImages[0];
    } else {
      imageUrl = adData['imageUrl'] ?? '';
    }
    final String title = adData['title'] ?? 'No Title';
    final String adDescription = adData['description'] ?? '';
    final Timestamp ts = (adData['createdAt'] is Timestamp)
        ? adData['createdAt'] as Timestamp
        : Timestamp.now();
    final DateTime createdAt = ts.toDate();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailScreen(
              ad: adData,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            _buildImage(imageUrl, width: 100, height: 100, fit: BoxFit.cover),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adDescription,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(createdAt, loc),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatRoomSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.chat,
      title: loc.translate('chat') ?? 'Chat',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatPage(
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('countries')
            .doc(_geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
            .collection('cities')
            .doc(_geoCity.isNotEmpty ? _geoCity : widget.cityId)
            .collection('locations')
            .doc(_geoNeighborhood.isNotEmpty
                ? _geoNeighborhood
                : widget.locationId)
            .collection('chats')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('error_loading_chats') ??
                        "Error loading chats.")));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('no_chat_messages_available') ??
                        "No chat messages available.")));
          }
          final docs = snapshot.data!.docs;
          final List<ChatModel> lastMessages = docs
              .map((doc) =>
                  ChatModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
          return Column(
            children: lastMessages
                .map((chat) => _buildSingleChatMessage(chat, loc))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildSingleChatMessage(ChatModel chat, LocalizationService loc) {
    final String profileImg = chat.profileImageUrl.isNotEmpty
        ? chat.profileImageUrl
        : 'assets/images/default_user.png';
    final String messageText = chat.text;
    final DateTime timeSent = chat.createdAt.toDate();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatPage(
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(child: _buildImage(profileImg, width: 40, height: 40)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.user.isNotEmpty ? chat.user : 'Unknown User',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (messageText.isNotEmpty)
                      Text(messageText, style: const TextStyle(fontSize: 14)),
                    if (chat.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: chat.imageUrl,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(_formatTimeAgo(timeSent, loc),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSection(LocalizationService loc) {
    final DateTime today = DateTime.now();
    final String todayId =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    return SectionCard(
      icon: Icons.quiz,
      title: loc.translate('quiz') ?? 'Kviz',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GamesScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('countries')
            .doc(_geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
            .collection('cities')
            .doc(_geoCity.isNotEmpty ? _geoCity : widget.cityId)
            .collection('locations')
            .doc(_geoNeighborhood.isNotEmpty
                ? _geoNeighborhood
                : widget.locationId)
            .collection('quizz')
            .doc(todayId)
            .collection('results')
            .orderBy('score', descending: true)
            .limit(10)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('error_loading_quiz_results') ??
                        "Error loading quiz results")));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('no_quiz_results_available') ??
                        "No quiz results available")));
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String userId = data['user_id'] ?? '';
              final String userName = data['username'] ?? 'Unknown';
              final int score = data['score'] as int? ?? 0;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: ProfileAvatar(userId: userId, radius: 25),
                  title: Text(
                    userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    "${loc.translate('score') ?? 'Score'}: $score",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildBulletinBoardSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.announcement,
      title: loc.translate('bulletin_board') ?? 'Bulletin Board',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BulletinBoardScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('countries')
            .doc(_geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
            .collection('cities')
            .doc(_geoCity.isNotEmpty ? _geoCity : widget.cityId)
            .collection('locations')
            .doc(_geoNeighborhood.isNotEmpty
                ? _geoNeighborhood
                : widget.locationId)
            .collection('bulletin_board')
            .orderBy('createdAt', descending: true)
            .limit(2)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('error_loading_data') ??
                        "Error loading data.")));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('no_data_available') ??
                        "No data available.")));
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final List<dynamic> imagePaths =
                  data['imagePaths'] ?? <dynamic>[];
              String firstImage = 'assets/images/bulletin.png';
              if (imagePaths.isNotEmpty && imagePaths[0] is String) {
                firstImage = imagePaths[0];
              }
              final String itemTitle = data['title'] as String? ?? '';
              final Timestamp ts = (data['createdAt'] is Timestamp)
                  ? data['createdAt'] as Timestamp
                  : Timestamp.now();
              final DateTime createdAt = ts.toDate();
              final Bulletin bullet = Bulletin.fromMap(data, doc.id);
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenBulletin(
                        bulletin: bullet,
                        username: widget.username,
                        countryId: widget.countryId,
                        cityId: widget.cityId,
                        locationId: widget.locationId,
                      ),
                    ),
                  );
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file,
                        size: 48, color: Colors.grey),
                    title: Text(
                      itemTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatTimeAgo(createdAt, loc),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.description,
      title: loc.translate('documents') ?? 'Documents',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentsScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      headerColor: Colors.grey,
      cardColor: Colors.orange[50],
      child: FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('countries')
            .doc(_geoCountry.isNotEmpty ? _geoCountry : widget.countryId)
            .collection('cities')
            .doc(_geoCity.isNotEmpty ? _geoCity : widget.cityId)
            .collection('locations')
            .doc(_geoNeighborhood.isNotEmpty
                ? _geoNeighborhood
                : widget.locationId)
            .collection('documents')
            .orderBy('createdAt', descending: true)
            .limit(2)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('error_loading_data') ??
                        "Error loading data.")));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(loc.translate('no_data_available') ??
                        "No data available.")));
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String itemTitle = data['title'] as String? ?? '';
              final Timestamp ts = (data['createdAt'] is Timestamp)
                  ? data['createdAt'] as Timestamp
                  : Timestamp.now();
              final DateTime createdAt = ts.toDate();
              return GestureDetector(
                onTap: () {
                  final docMap = {'id': doc.id, ...data};
                  _openDocument(docMap);
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file,
                        size: 48, color: Colors.grey),
                    title: Text(
                      itemTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatTimeAgo(createdAt, loc),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildBukaSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.construction,
      title: loc.translate('noise') ?? 'Buka',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConstructionScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: _works.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  loc.translate('no_active_works') ?? "Trenutno nema radova."),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _works.length,
              itemBuilder: (context, index) {
                final work = _works[index];
                final String description = work['description'] ?? '';
                final String details = work['details'] ?? '';
                final DateTime startDate = DateTime.parse(work['startDate']);
                final DateTime endDate = DateTime.parse(work['endDate']);
                final dateFormat = DateFormat('dd.MM.yyyy');
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(description,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 5),
                        Text(details),
                        const SizedBox(height: 5),
                        Text(
                            '${loc.translate('date') ?? 'Date'}: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _fetchParkingPreview() async {
    try {
      final stream = _parkingScheduleService.getParkingRequests(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );
      final allRequests = await stream.first;
      final pending =
          allRequests.where((req) => req.status == 'pending').take(2).toList();
      setState(() {
        _parkingPreview = pending;
      });
    } catch (e) {
      debugPrint("Error fetching parking preview: $e");
      setState(() {
        _parkingPreview = [];
      });
    }
  }

  Widget _buildParkingSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.local_parking,
      title: loc.translate('parking') ?? 'Parking',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParkingCommunityScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
              locationAdmin: widget.locationAdmin,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _parkingPreview.isEmpty
            ? Text(loc.translate('no_active_parking_requests') ??
                "Trenutno nema aktivnih (pending) parking zahtjeva.")
            : Column(
                children: _parkingPreview.map((req) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParkingCommunityScreen(
                            username: widget.username,
                            countryId: widget.countryId,
                            cityId: widget.cityId,
                            locationId: widget.locationId,
                            locationAdmin: widget.locationAdmin,
                          ),
                        ),
                      );
                    },
                    child: _buildSingleParkingRequestPreview(req, loc),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildSingleParkingRequestPreview(
      ParkingRequest req, LocalizationService loc) {
    final String timeString =
        "${_formatDateTime(req.startDate, req.startTime)} - ${_formatDateTime(req.endDate, req.endTime)}";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${loc.translate('parking_request_for') ?? "Zahtjev za"} ${req.numberOfSpots} ${loc.translate('spot_s') ?? "mjesto(a)"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(timeString,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (req.message.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(req.message,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchCommutePreview() async {
    try {
      final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
      await rideViewModel.initRides(
        const GeoPoint(45.8150, 15.9819),
        5.0,
        _auth.currentUser?.uid ?? '',
      );
      final ridesList = await rideViewModel.availableRidesStream.first;
      final DateTime now = DateTime.now();
      final preview = ridesList
          .where((ride) =>
              ride.status == RideStatus.open &&
              ride.departureTime.isAfter(now) &&
              (ride.seatsAvailable > ride.passengers.length))
          .take(2)
          .toList();
      setState(() {
        _commutePreview = preview;
      });
    } catch (e) {
      debugPrint("Error fetching commute preview: $e");
      setState(() {
        _commutePreview = [];
      });
    }
  }

  Widget _buildCommuteSection(LocalizationService loc) {
    return SectionCard(
      icon: Icons.directions_car,
      title: loc.translate('commute') ?? 'Zajednički prijevoz',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommuteRidesListScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        );
      },
      child: _commutePreview.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(loc.translate('no_offered_rides') ??
                  "Trenutno nema ponuđenih vožnji."),
            )
          : Column(
              children: _commutePreview
                  .map((ride) => GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommuteRideDetailScreen(
                                rideId: ride.rideId,
                                userId: _auth.currentUser?.uid ?? '',
                              ),
                            ),
                          );
                        },
                        child: CommutePreviewCard(
                          ride: ride,
                          loc: loc,
                          formatTimeAgo: _formatTimeAgo,
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Future<void> _openDocument(Map<String, dynamic> docData) async {
    try {
      final url = docData['filePath'];
      final fileType = docData['fileType'];
      final title = docData['title'] ?? 'document';

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$title.$fileType';
      final file = File(filePath);

      if (!(await file.exists())) {
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentPreviewScreen(
            filePath: filePath,
            fileType: fileType,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LocalizationService loc =
        Provider.of<LocalizationService>(context, listen: true);

    // Omotavamo sadržaj u RefreshIndicator kako bismo omogućili pull-to-refresh
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 8),
                LastPostsSection(
                  fetchPosts: _fetchLastPosts,
                  username: widget.username,
                  locationAdmin: widget.locationAdmin,
                ),
                const SizedBox(height: 16),
                OfficialNoticesSection(
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  geoCountry: _geoCountry,
                  geoCity: _geoCity,
                  geoNeighborhood: _geoNeighborhood,
                  locationAdmin: widget.locationAdmin,
                  firestore: _firestore,
                ),
                const SizedBox(height: 16),
                MarketplaceSection(
                  fetchAds: _fetchLastMarketplaceAds,
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                ),
                const SizedBox(height: 16),
                ChatRoomSection(
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  geoCountry: _geoCountry,
                  geoCity: _geoCity,
                  geoNeighborhood: _geoNeighborhood,
                  firestore: _firestore,
                ),
                const SizedBox(height: 16),
                ParkingSection(
                  parkingPreview: _parkingPreview,
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  locationAdmin: widget.locationAdmin,
                  formatDateTime: _formatDateTime,
                ),
                const SizedBox(height: 16),
                CommuteSection(
                  commutePreview: _commutePreview,
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  auth: _auth,
                  formatTimeAgo: _formatTimeAgo,
                ),
                const SizedBox(height: 16),
                QuizSection(
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  geoCountry: _geoCountry,
                  geoCity: _geoCity,
                  geoNeighborhood: _geoNeighborhood,
                  firestore: _firestore,
                ),
                const SizedBox(height: 16),
                BulletinBoardSection(
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  geoCountry: _geoCountry,
                  geoCity: _geoCity,
                  geoNeighborhood: _geoNeighborhood,
                  firestore: _firestore,
                ),
                const SizedBox(height: 16),
                DocumentsSection(
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                  geoCountry: _geoCountry,
                  geoCity: _geoCity,
                  geoNeighborhood: _geoNeighborhood,
                  firestore: _firestore,
                  openDocument: _openDocument,
                ),
                const SizedBox(height: 16),
                // Mudra sova – bez navigacije
                SectionCard(
                  icon: Icons.book,
                  title: loc.translate('wise_owl') ?? 'Mudra sova',
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _dailySaying == null
                        ? const Center(child: CircularProgressIndicator())
                        : Text(
                            _dailySaying!,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                BukaSection(
                  works: _works,
                  username: widget.username,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
