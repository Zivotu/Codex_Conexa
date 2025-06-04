// lib/local/screens/local_home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/location_service.dart';
import '../../services/user_service.dart';
import 'post_widget.dart';
import 'create_post_screen.dart';
import '../../screens/user_locations_screen.dart';
import 'post_detail_screen.dart';
import 'like_notifications_screen.dart';
import '../services/post_correction_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../constants/location_constants.dart';
import '../../services/localization_service.dart';

// ** DODANO: importi za ekrane koji nisu “prepoznati” **
import '../../screens/login_screen.dart';
import '../../screens/location_details_screen.dart';
import '../../screens/servicer_dashboard_screen.dart';

class LocalHomeScreen extends StatefulWidget {
  final String username;
  final bool locationAdmin;

  const LocalHomeScreen({
    super.key,
    required this.username,
    required this.locationAdmin,
  });

  @override
  LocalHomeScreenState createState() => LocalHomeScreenState();
}

class LocalHomeScreenState extends State<LocalHomeScreen>
    with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();
  final PostCorrectionService _postCorrectionService = PostCorrectionService();
  final Logger _logger = Logger();

  String _geoLocalCountryId = LocationConstants.UNKNOWN_COUNTRY;
  String _geoLocalCityId = LocationConstants.UNKNOWN_CITY;
  String _geoLocalNeighborhoodId = LocationConstants.UNKNOWN_NEIGHBORHOOD;
  String _currentLevel = 'neighborhood';
  bool _isGridView = true;

  int _recentPostsCount = 0;
  int _cityPostsCount = 0;
  int _countryPostsCount = 0;
  int _likeNotificationsCount = 0;
  Timestamp? _lastLikeCheck;

  String _username = 'Unknown';
  String _profileImageUrl = '';
  bool _isAnonymous = false;
  String _version = '';

  late AnimationController _controller;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamSubscription<QuerySnapshot>? _userPostsSubscription;
  String _previousCityId = LocationConstants.UNKNOWN_CITY;

  /// Popis svih korisnikovih lokacija (jedinstvene, filtrirane)
  List<Map<String, dynamic>> userLocations = [];
  Map<String, Map<String, int>> newContentCounts = {};

  @override
  void initState() {
    super.initState();
    _logger.i('LocalHomeScreen initialized');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadAppVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLastViewedLevel();
      await _loadAnonymousMode();
      await _determineUserLocation();
      await _updatePostCounts();
      await _loadUserProfile();
      await _loadLastLikeCheck();
      await _updateLikeNotificationsCount();
      await _checkUnknownPosts();
      _listenToUserPosts();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _userPostsSubscription?.cancel();
    super.dispose();
  }

  void _showError(String messageKey) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizationService.translate(messageKey) ?? messageKey),
      ),
    );
  }

  void _listenToUserPosts() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _logger.w('User ID je null. Ne mogu slušati korisničke postove.');
      return;
    }

    _userPostsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('userPosts')
        .snapshots()
        .listen((snapshot) {
      int newLikes = 0;
      for (var doc in snapshot.docs) {
        final postData = doc.data();
        final lastLikedAt = postData['lastLikedAt'] as Timestamp?;
        if (lastLikedAt != null && _lastLikeCheck != null) {
          if (lastLikedAt.compareTo(_lastLikeCheck!) > 0) {
            newLikes += 1;
          }
        } else if (lastLikedAt != null && _lastLikeCheck == null) {
          newLikes += 1;
        }
      }
      setState(() {
        _likeNotificationsCount = newLikes;
      });
      _logger.i('Real-time update: $_likeNotificationsCount new likes.');
    }, onError: (error) {
      _logger.e('Greška u slušanju korisničkih postova: $error');
    });
  }

  Future<void> _loadAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _checkUnknownPosts() async {
    _logger.i('Checking for posts in Unknown collections...');
    await _postCorrectionService.correctUnknownLocationPosts();
  }

  Future<void> _saveLastViewedLevel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastViewedLevel', _currentLevel);
    await prefs.setString('lastViewedCountryId', _geoLocalCountryId);
    await prefs.setString('lastViewedCityId', _geoLocalCityId);
    await prefs.setString('lastViewedNeighborhoodId', _geoLocalNeighborhoodId);
  }

  Future<void> _loadLastViewedLevel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLevel = prefs.getString('lastViewedLevel') ?? 'neighborhood';
      _geoLocalCountryId = prefs.getString('lastViewedCountryId') ??
          LocationConstants.UNKNOWN_COUNTRY;
      _geoLocalCityId =
          prefs.getString('lastViewedCityId') ?? LocationConstants.UNKNOWN_CITY;
      _geoLocalNeighborhoodId = prefs.getString('lastViewedNeighborhoodId') ??
          LocationConstants.UNKNOWN_NEIGHBORHOOD;
    });
  }

  bool _isLoadingProfile = true;

  Future<void> _loadUserProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await _userService.getUserDocument(currentUser);
        if (userDoc != null) {
          setState(() {
            _username = userDoc['username'] ?? 'Unknown';
            _profileImageUrl = userDoc['profileImageUrl'] ?? '';
          });
        } else {
          _logger.w('User document not found.');
        }
      }
    } catch (e) {
      _logger.e('Error loading user profile: $e');
    } finally {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  /// UMJESTO BLOKIRANJA, postavljamo UNKNOWN
  Future<void> _determineUserLocation() async {
    _logger.i('Determining user location...');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('Location service not enabled. Setting location to UNKNOWN');
      setState(() {
        _geoLocalCountryId = LocationConstants.UNKNOWN_COUNTRY;
        _geoLocalCityId = LocationConstants.UNKNOWN_CITY;
        _geoLocalNeighborhoodId = LocationConstants.UNKNOWN_NEIGHBORHOOD;
      });
      _fetchUserLocations();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      _logger.w('Location permission denied, requesting permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _logger.e(
            'Location permission request failed. Setting location to UNKNOWN');
        setState(() {
          _geoLocalCountryId = LocationConstants.UNKNOWN_COUNTRY;
          _geoLocalCityId = LocationConstants.UNKNOWN_CITY;
          _geoLocalNeighborhoodId = LocationConstants.UNKNOWN_NEIGHBORHOOD;
        });
        _fetchUserLocations();
        return;
      }
    }

    try {
      Position locationData = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      _logger.i('Location acquired: lat=$lat, lng=$lng');

      final geoData = await _locationService.getGeographicalData(lat, lng);
      _logger.i('Geographical data: $geoData');

      if (mounted) {
        setState(() {
          _geoLocalCountryId =
              geoData['country'] ?? LocationConstants.UNKNOWN_COUNTRY;
          _geoLocalCityId = geoData['city'] ?? LocationConstants.UNKNOWN_CITY;
          _geoLocalNeighborhoodId =
              geoData['neighborhood'] ?? LocationConstants.UNKNOWN_NEIGHBORHOOD;
        });

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null &&
            _geoLocalCityId != LocationConstants.UNKNOWN_CITY) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'currentCityId': _geoLocalCityId});
        }

        await _updateCitySubscription(_geoLocalCityId, _previousCityId);
        _previousCityId = _geoLocalCityId;
      }
    } catch (e) {
      _logger.e('Error determining user location: $e');
      _logger.w('Setting location to UNKNOWN');
      setState(() {
        _geoLocalCountryId = LocationConstants.UNKNOWN_COUNTRY;
        _geoLocalCityId = LocationConstants.UNKNOWN_CITY;
        _geoLocalNeighborhoodId = LocationConstants.UNKNOWN_NEIGHBORHOOD;
      });
    }

    await _fetchUserLocations();
  }

  /// Pretplata / odjava na FCM temu grada
  Future<void> _updateCitySubscription(
      String newCityId, String oldCityId) async {
    if (oldCityId.isNotEmpty && oldCityId != LocationConstants.UNKNOWN_CITY) {
      try {
        await FirebaseMessaging.instance
            .unsubscribeFromTopic('city_$oldCityId');
        _logger.i('Unsubscribed from topic: city_$oldCityId');
      } catch (e) {
        _logger.e('Error unsubscribing from topic city_$oldCityId: $e');
      }
    }
    if (newCityId.isNotEmpty && newCityId != LocationConstants.UNKNOWN_CITY) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic('city_$newCityId');
        _logger.i('Subscribed to topic: city_$newCityId');
      } catch (e) {
        _logger.e('Error subscribing to topic city_$newCityId: $e');
      }
    }
  }

  /// Učitaj anonimni mod od zadnjeg puta
  Future<void> _loadAnonymousMode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _isAnonymous = userDoc['isAnonymous'] ?? false;
        });
      }
    }
  }

  Future<void> _loadLastLikeCheck() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _lastLikeCheck = userDoc['lastLikeCheck'] as Timestamp?;
        });
      }
    }
  }

  Future<void> _updateLikeNotificationsCount() async {
    _logger.i('Updating like notifications count...');
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final lastCheck = _lastLikeCheck ?? Timestamp.fromDate(DateTime(2000));

      QuerySnapshot userPostsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .where('lastLikedAt', isGreaterThan: lastCheck)
          .get();

      setState(() {
        _likeNotificationsCount = userPostsSnapshot.size;
      });
      _logger.i('Notification count updated: $_likeNotificationsCount');
    } catch (error) {
      _logger.e('Error updating notification count: $error');
    }
  }

  Future<void> _updatePostCounts() async {
    _logger.i('Updating post counts...');
    DateTime oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));

    int recentPostsCount = 0;
    int cityPostsCount = 0;
    int countryPostsCount = 0;

    recentPostsCount += await _getPostCount(
      _geoLocalCountryId,
      _geoLocalCityId,
      _geoLocalNeighborhoodId,
      oneHourAgo,
      isNeighborhood: true,
    );

    cityPostsCount += await _getPostCount(
      _geoLocalCountryId,
      _geoLocalCityId,
      '',
      oneHourAgo,
      isCity: true,
    );

    countryPostsCount += await _getPostCount(
      _geoLocalCountryId,
      '',
      '',
      oneHourAgo,
      isCountry: true,
    );

    if (mounted) {
      _controller.reset();
      setState(() {
        _recentPostsCount = recentPostsCount;
        _cityPostsCount = cityPostsCount;
        _countryPostsCount = countryPostsCount;
        _logger.i(
            'Post counts updated: Neighborhood $_recentPostsCount, City $_cityPostsCount, Country $_countryPostsCount');
      });
      _controller.forward();
    }
  }

  Future<int> _getPostCount(
    String localCountryId,
    String localCityId,
    String localNeighborhoodId,
    DateTime startDateTime, {
    bool isNeighborhood = false,
    bool isCity = false,
    bool isCountry = false,
  }) async {
    int postCount = 0;
    if (localCountryId.isEmpty ||
        (isCity && localCityId.isEmpty) ||
        (isNeighborhood && localNeighborhoodId.isEmpty)) {
      _logger.w(
          'Invalid path: localCountryId=$localCountryId, localCityId=$localCityId, localNeighborhoodId=$localNeighborhoodId');
      return 0;
    }

    String collectionGroupName =
        'posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}';

    QuerySnapshot postsSnapshot = await FirebaseFirestore.instance
        .collectionGroup(collectionGroupName)
        .where(
            isCountry
                ? 'localCountryId'
                : isCity
                    ? 'localCityId'
                    : 'localNeighborhoodId',
            isEqualTo: isCountry
                ? localCountryId
                : isCity
                    ? localCityId
                    : localNeighborhoodId)
        .where('createdAt', isGreaterThanOrEqualTo: startDateTime)
        .get();

    postCount += postsSnapshot.size;
    return postCount;
  }

  void _changeLevel(String level) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    _logger.i('Changing level to: $level');
    setState(() {
      _currentLevel = level;
      _saveLastViewedLevel();
      _updatePostCounts();
    });
  }

  void _navigateToLikeNotifications() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    _logger.i('Navigating to like notifications screen...');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LikeNotificationsScreen(),
      ),
    ).then((_) async {
      if (mounted) {
        setState(() {
          _likeNotificationsCount = 0;
        });
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final now = Timestamp.now();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'lastLikeCheck': now});
          setState(() {
            _lastLikeCheck = now;
          });
        }
      }
    });
  }

  void _navigateToCreatePost() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    _logger.i('Navigating to create post screen...');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          localCountryId: _geoLocalCountryId,
          localCityId: _geoLocalCityId,
          isAnonymous: _isAnonymous,
          username: _isAnonymous
              ? (localizationService.translate('anonymous') ?? 'Anonimus')
              : _username,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _updatePostCounts();
      }
    });
  }

  /// **DIO 1: Dohvat korisnikovih “aktivnih” lokacija iz firestore i filtracija**
  Future<void> _fetchUserLocations() async {
    _logger.d('Fetching user locations...');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(user.uid)
            .collection('locations')
            .where('deleted', isEqualTo: false)
            .where('status', whereIn: ['joined', 'pending']).get();

        List<Map<String, dynamic>> filteredLocations = [];

        for (var locationDoc in snapshot.docs) {
          var location = locationDoc.data() as Map<String, dynamic>;

          // dohvatamo “glavnu” docs iz kolekcije “locations” da dobijemo sve detalje
          final locationDataSnapshot = await FirebaseFirestore.instance
              .collection('locations')
              .doc(location['locationId'])
              .get();

          if (locationDataSnapshot.exists) {
            Map<String, dynamic> realLocData = locationDataSnapshot.data()!;

            // logika za filtriranje: samo admin, superAllow ili aktivne/trialActive i ne-istrošene
            final bool isAdmin = location['locationAdmin'] == true ||
                realLocData['ownedBy'] == user.uid;
            final String activationType =
                realLocData['activationType'] ?? 'inactive';
            final Timestamp? activeUntilTs = realLocData['activeUntil'];
            bool isExpired = false;
            if (activeUntilTs != null) {
              isExpired = activeUntilTs.toDate().isBefore(DateTime.now());
            }
            final bool superAllow = realLocData['superAllow'] ?? false;

            bool canShow = isAdmin ||
                superAllow ||
                ((activationType == 'active' ||
                        activationType == 'trialActive') &&
                    !isExpired);

            if (!canShow) {
              continue;
            }

            Map<String, dynamic> combinedLocation = {
              ...location,
              'locationName': realLocData['name'] ??
                  Provider.of<LocalizationService>(context, listen: false)
                      .translate('unknownLocation'),
              'countryId': realLocData['countryId'] ?? '',
              'cityId': realLocData['cityId'] ?? '',
              'imagePath': realLocData['imagePath'] ?? '',
              'neighborhoodId': realLocData['neighborhoodId'] ?? '',
            };
            filteredLocations.add(combinedLocation);
          } else {
            _logger.d(
                'Location does not exist in database: ${location['locationId']}');
          }
        }

        if (!mounted) return;
        setState(() {
          userLocations = filteredLocations;
          _logger.d('User locations updated: $userLocations');

          // Ako je samo jedna lokacija – automatski otvorimo njen details
          if (userLocations.length == 1) {
            _logger.d('One location found, navigating to details...');
            _navigateToLocation(userLocations[0]);
          }
        });
        await _precacheLocationImages();
        await _fetchAllNewContentCounts();
        await _checkActiveRepairRequests();
      } catch (e) {
        _logger.e('Error fetching user locations: $e');
        if (!mounted) return;
        setState(() {
          userLocations = [];
        });
        await _checkActiveRepairRequests();
      }
    } else {
      _logger.w('No user is logged in');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      });
    }
  }

  Future<void> _precacheLocationImages() async {
    for (var location in userLocations) {
      String imagePath = location['imagePath'] ?? '';
      try {
        if (imagePath.startsWith('http')) {
          await precacheImage(NetworkImage(imagePath), context);
        } else {
          await precacheImage(
            AssetImage(imagePath.isNotEmpty ? imagePath : ''),
            context,
          );
        }
      } catch (e) {
        _logger.e('Error pre-caching image: $e');
      }
    }
    _logger.d('All location images have been pre-cached.');
  }

  Future<void> _checkActiveRepairRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {});
      return;
    }

    try {
      QuerySnapshot activeRepairsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('repair_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: [
        'Published',
        'In Negotiation',
        'Job Agreed',
        'waitingforconfirmation',
        'published_2',
      ]).get();

      if (!mounted) return;
      setState(() {});
      _logger.i(
          'Korisnik ima aktivne popravke: ${activeRepairsSnapshot.docs.isNotEmpty}');
    } catch (e) {
      _logger.e('Error checking active repair requests: $e');
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _fetchAllNewContentCounts() async {
    DateTime last24h = DateTime.now().subtract(const Duration(hours: 24));
    Map<String, Map<String, int>> countsMap = {};

    for (var location in userLocations) {
      final countryId = (location['countryId'] ?? '').toString();
      final cityId = (location['cityId'] ?? '').toString();
      final locationId = (location['locationId'] ?? '').toString();

      // Ako je bilo koji ID prazan, preskoči i postavi sve brojače na 0
      if (countryId.isEmpty || cityId.isEmpty || locationId.isEmpty) {
        _logger.w(
            'Preskačem sadržaje za locationId="$locationId" jer nedostaje jedan od ID-jeva: '
            'country="$countryId", city="$cityId", location="$locationId"');
        countsMap[locationId] = {
          'chat': 0,
          'officialNotices': 0,
          'bulletinBoard': 0,
          'documents': 0,
        };
        continue;
      }

      try {
        final chatSnapshot = await FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('chats')
            .where('createdAt', isGreaterThanOrEqualTo: last24h)
            .get();
        final officialNoticesSnapshot = await FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('blogs')
            .where('createdAt', isGreaterThanOrEqualTo: last24h)
            .get();
        final bulletinBoardSnapshot = await FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('bulletin_board')
            .where('createdAt', isGreaterThanOrEqualTo: last24h)
            .get();
        final documentsSnapshot = await FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('documents')
            .where('createdAt', isGreaterThanOrEqualTo: last24h)
            .get();

        countsMap[locationId] = {
          'chat': chatSnapshot.size,
          'officialNotices': officialNoticesSnapshot.size,
          'bulletinBoard': bulletinBoardSnapshot.size,
          'documents': documentsSnapshot.size,
        };

        _logger.i(
            "Fetched new content counts for location $locationId: ${countsMap[locationId]}");
      } catch (e) {
        _logger.e('Error fetching content counts for location $locationId: $e');
        countsMap[locationId] = {
          'chat': 0,
          'officialNotices': 0,
          'bulletinBoard': 0,
          'documents': 0,
        };
      }
    }

    if (!mounted) return;
    setState(() {
      newContentCounts = countsMap;
    });
    _logger.d('All new content counts have been fetched and stored.');
  }

  void _showNoLocationsDialog() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.translate('noLocationsTitle') ?? 'Obavijest'),
        content: Text(loc.translate('noLocationsMessage') ??
            'Ukoliko vidite ovu poruku to znači da još niste član niti jedne virtualne zajednice, predlažemo Vam da kreirate vlastitu, kreiranje "lokacije" je besplatno, a omogućit će vam brojne korisne module i funkcionalnosti!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.translate('ok') ?? 'OK'),
          )
        ],
      ),
    );
  }

  void _navigateToLocation(Map<String, dynamic> location) {
    if (location['locationId'] != null && location['countryId'] != null) {
      _logger.d('Navigating to location: $location');
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationDetailsScreen(
            countryId: location['countryId'] ?? '',
            cityId: location['cityId'] ?? '',
            locationId: location['locationId'] ?? '',
            username: widget.username,
            displayName: location['locationName'] ?? '',
            locationAdmin: location['locationAdmin'] ?? false,
          ),
        ),
      ).then((_) {
        if (mounted) {
          _checkActiveRepairRequests();
        }
      });
    } else {
      _logger.e('Missing location data: $location');
      final loc = Provider.of<LocalizationService>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('incompleteLocationData') ??
                'Greška: Nepotpuni podaci o lokaciji.'),
          ),
        );
      }
    }
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userData.exists && mounted) {
          setState(() {
            // Ovaj komad sada samo inicijalno postavlja
          });
        }
      } catch (e) {
        _logger.e('Error checking user type: $e');
      }
    }
  }

  Future<void> _navigateToServicerDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final loc = Provider.of<LocalizationService>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('userNotLoggedIn') ??
                'Korisnik nije prijavljen.'),
          ),
        );
      }
      return;
    }

    try {
      final servicerDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(user.uid)
          .get();

      if (!servicerDoc.exists) {
        final loc = Provider.of<LocalizationService>(context, listen: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('servicerDataNotFound') ??
                  'Podaci servisera nisu pronađeni.'),
            ),
          );
        }
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServicerDashboardScreen(
            username: widget.username,
          ),
        ),
      ).then((_) {
        if (mounted) {
          _checkActiveRepairRequests();
        }
      });
    } catch (e) {
      final loc = Provider.of<LocalizationService>(context, listen: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(loc.translate('servicerNavigationError') ?? 'Greška: $e'),
          ),
        );
      }
    }
  }

  Widget _buildLevelDisplay(LocalizationService localizationService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLevelText(
          _geoLocalCountryId,
          _countryPostsCount,
          _currentLevel == 'country',
          localizationService,
          'country',
        ),
        const SizedBox(height: 1),
        _buildLevelText(
          _geoLocalCityId,
          _cityPostsCount,
          _currentLevel == 'city',
          localizationService,
          'city',
        ),
        const SizedBox(height: 1),
        _buildLevelText(
          _geoLocalNeighborhoodId,
          _recentPostsCount,
          _currentLevel == 'neighborhood',
          localizationService,
          'neighborhood',
        ),
      ],
    );
  }

  Widget _buildLevelText(String text, int postCount, bool isCurrentLevel,
      LocalizationService localizationService, String levelType) {
    String displayText = text;
    if (text == LocationConstants.UNKNOWN_NEIGHBORHOOD) {
      displayText = localizationService.translate('unknown_neighborhood') ??
          'unknown_neighborhood';
    }
    if (text == LocationConstants.UNKNOWN_CITY) {
      displayText =
          localizationService.translate('unknown_city') ?? 'unknown_city';
    }
    if (text == LocationConstants.UNKNOWN_COUNTRY) {
      displayText =
          localizationService.translate('unknown_country') ?? 'unknown_country';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          displayText.toUpperCase(),
          style: TextStyle(
            color:
                isCurrentLevel ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: isCurrentLevel ? 16 : 12,
            fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (postCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              '$postCount',
              style: TextStyle(
                color: isCurrentLevel
                    ? Colors.white.withOpacity(0.7)
                    : Colors.white.withOpacity(0.3),
                fontSize: isCurrentLevel ? 14 : 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostsColumn(LocalizationService localizationService) {
    return RefreshIndicator(
      onRefresh: _updatePostCounts,
      child: StreamBuilder<List<QuerySnapshot>>(
        stream: _getPostsStreams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            _logger.i('Loading posts...');
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue,
                ),
              ),
            );
          } else if (snapshot.hasError) {
            _logger.e('Error loading posts: ${snapshot.error}');
            return Center(
              child: Text(
                  localizationService.translate('failed_to_load_posts') ??
                      'Failed to load posts: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            _logger.w('No posts available');
            return Center(
              child: Text(localizationService.translate('no_posts_available') ??
                  'No posts available'),
            );
          } else {
            final items = snapshot.data!
                .expand((qs) => qs.docs)
                .map((doc) => {
                      'postId': doc.id,
                      ...doc.data() as Map<String, dynamic>,
                    })
                .where((post) =>
                    post['mediaUrl'] != null && post['mediaUrl'] != '')
                .toList();

            _logger.i('Loaded ${items.length} items');
            return _isGridView ? _buildGridView(items) : _buildListView(items);
          }
        },
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return GestureDetector(
          onTap: () => _navigateToPostDetail(context, item),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            margin: const EdgeInsets.all(2.0),
            child: PostWidget(
              postData: item,
              isGridView: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        childAspectRatio: 9 / 15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _navigateToPostDetail(context, item),
          child: PostWidget(
            postData: item,
            isGridView: true,
          ),
        );
      },
    );
  }

  void _navigateToPostDetail(BuildContext context, Map<String, dynamic> post) {
    _logger.i('Navigating to post detail: ${post['postId']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  Stream<List<QuerySnapshot>> _getPostsStreams() {
    final now = DateTime.now();
    List<Stream<QuerySnapshot>> monthlyStreams = [];

    for (int i = 0; i < 6; i++) {
      final targetDate = DateTime(now.year, now.month - i);
      final targetMonth = targetDate.month.toString().padLeft(2, '0');
      final collectionName = 'posts_${targetDate.year}_$targetMonth';

      final stream = FirebaseFirestore.instance
          .collectionGroup(collectionName)
          .where(
            _currentLevel == 'neighborhood'
                ? 'localNeighborhoodId'
                : _currentLevel == 'city'
                    ? 'localCityId'
                    : 'localCountryId',
            isEqualTo: _currentLevel == 'neighborhood'
                ? _geoLocalNeighborhoodId
                : _currentLevel == 'city'
                    ? _geoLocalCityId
                    : _geoLocalCountryId,
          )
          .orderBy('createdAt', descending: true)
          .snapshots();

      monthlyStreams.add(stream);
    }

    return Rx.combineLatestList(monthlyStreams);
  }

  /// ********************** DRAWER **********************
  Widget _buildMenu(LocalizationService localizationService) {
    return Drawer(
      child: Container(
        color:
            _isAnonymous ? Colors.black : const Color.fromRGBO(50, 47, 53, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAccountsDrawerHeader(
              decoration:
                  const BoxDecoration(color: Color.fromRGBO(34, 34, 34, 1)),
              accountName: Text(
                _isAnonymous
                    ? localizationService.translate('anonymous') ?? 'Anonimus'
                    : _username,
                style: const TextStyle(color: Colors.white),
              ),
              accountEmail: const Text(''),
              currentAccountPicture: _isAnonymous
                  ? const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white, size: 40),
                    )
                  : CircleAvatar(
                      backgroundImage: _profileImageUrl.startsWith('http')
                          ? NetworkImage(_profileImageUrl)
                          : const AssetImage('assets/images/default_user.png')
                              as ImageProvider,
                    ),
            ),

            // ** 1) Prvo, samo one lokacije koje su aktivne (userLocations) **
            if (userLocations.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  localizationService.translate('my_active_locations') ??
                      'Moje (aktivne) lokacije',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: userLocations.length,
                  itemBuilder: (context, index) {
                    final loc = userLocations[index];
                    String imagePath = (loc['imagePath'] != null &&
                            loc['imagePath'].toString().trim().isNotEmpty)
                        ? loc['imagePath']
                        : '';
                    bool isNetwork = imagePath.startsWith('http');

                    return ListTile(
                      leading: isNetwork
                          ? Image.network(
                              imagePath,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.home, color: Colors.white),
                                );
                              },
                            )
                          : (imagePath.isNotEmpty
                              ? Image.asset(
                                  imagePath,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : const CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.home, color: Colors.white),
                                )),
                      title: Text(
                        loc['locationName'] ??
                            localizationService.translate('unknownLocation') ??
                            'Nepoznato',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${loc['cityId'] ?? ''}, ${loc['countryId'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToLocation(loc);
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white54),
            ],

            // ** 2) Zadržati sve originalne stavke iz Drawer–a **

            ListTile(
              leading: const Icon(Icons.home, color: Colors.white),
              title: Text(
                localizationService.translate('home') ?? 'Home',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserLocationsScreen(
                      username: widget.username,
                    ),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white54),

            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.white),
              title: Text(
                localizationService.translate('my_locations') ??
                    'Moje lokacije',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserLocationsScreen(
                      username: widget.username,
                    ),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.white),
              title: Text(
                localizationService.translate('filter_by_trending') ??
                    'Filtriraj po popularnosti',
                style: const TextStyle(color: Color.fromRGBO(118, 118, 118, 1)),
              ),
              onTap: () {
                // TODO: implementirajte filtriranje po popularnosti
              },
            ),

            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.white),
              title: Text(
                localizationService.translate('filter_by_date') ??
                    'Filtriraj po datumu',
                style: const TextStyle(color: Color.fromRGBO(118, 118, 118, 1)),
              ),
              onTap: () {
                // TODO: implementirajte filtriranje po datumu
              },
            ),

            ListTile(
              leading: const Icon(Icons.view_agenda, color: Colors.white),
              title: Text(
                localizationService.translate('large_view') ?? 'Veći pregled',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() {
                  _isGridView = false;
                });
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.grid_view, color: Colors.white),
              title: Text(
                localizationService.translate('small_view') ?? 'Manji pregled',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() {
                  _isGridView = true;
                });
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            // ** 3) SwitchListTile (Anonymous) – samo ako korisnik to odabere, a inače uzmi iz Firestorea **
            SwitchListTile(
              title: Text(
                localizationService.translate('anonymous') ?? 'Anonymous',
                style: const TextStyle(color: Colors.white),
              ),
              value: _isAnonymous,
              onChanged: (value) async {
                setState(() {
                  _isAnonymous = value;
                });
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .update({'isAnonymous': value});
                }
              },
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);

    return Scaffold(
      key: _scaffoldKey,
      body: Column(
        children: [
          Container(
            color: _isAnonymous
                ? Colors.black
                : const Color.fromRGBO(50, 47, 53, 1),
            width: double.infinity,
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu),
                          color: Colors.white,
                          iconSize: 40,
                          onPressed: () {
                            _logger.i('Opening menu');
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                        ),
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications),
                              color: Colors.white,
                              iconSize: 20,
                              onPressed: _navigateToLikeNotifications,
                            ),
                            if (_likeNotificationsCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$_likeNotificationsCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! > 0) {
                            _logger.i('User swiped down');
                            if (_currentLevel == 'neighborhood') {
                              _changeLevel('city');
                            } else if (_currentLevel == 'city') {
                              _changeLevel('country');
                            }
                          } else if (details.primaryVelocity! < 0) {
                            _logger.i('User swiped up');
                            if (_currentLevel == 'country') {
                              _changeLevel('city');
                            } else if (_currentLevel == 'city') {
                              _changeLevel('neighborhood');
                            }
                          }
                        }
                      },
                      child: _buildLevelDisplay(localizationService),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Color.fromARGB(255, 3, 208, 71)),
                      iconSize: 70,
                      onPressed: _navigateToCreatePost,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '${localizationService.translate('version') ?? 'Verzija'}: $_version',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildPostsColumn(localizationService),
          ),
        ],
      ),
      endDrawer: _buildMenu(localizationService),
    );
  }
}
