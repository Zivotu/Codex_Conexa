import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../local/screens/local_home_screen.dart';
import 'location_details_screen.dart';
import 'create_location_screen.dart';
import 'join_location_screen.dart';
import 'new_servicer_registration_screen.dart';
import 'servicer_dashboard_screen.dart'; // Servicer Dashboard Screen
import 'report_issue_screen.dart'; // Report Issue Screen
import 'adverts_info_screen.dart'; // Adverts Info Screen
import 'onboarding_screen.dart'; // OnboardingScreen
import 'settings_screen.dart';
import 'login_screen.dart';
import '../services/location_service.dart';
import '../services/localization_service.dart';
import 'affiliate_dashboard_screen.dart'; // NOVO
import 'affiliate_supplement_screen.dart';

import 'affiliate_existing_login_screen.dart';

class UserLocationsScreen extends StatefulWidget {
  final String username;

  const UserLocationsScreen({super.key, required this.username});

  @override
  UserLocationsScreenState createState() => UserLocationsScreenState();
}

class UserLocationsScreenState extends State<UserLocationsScreen>
    with RouteAware {
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> userLocations = [];
  String _geoLocalCityId = '';
  String _geoLocalCountryId = '';
  bool _isServicer = false;
  bool _affiliateActive = false;

  int _currentModuleIndex = 0;
  Timer? _moduleSwitchTimer;

  // Ključevi za module – svi tekstovi se lokaliziraju pomoću LocalizationService
  final List<Map<String, String>> _modules = [
    {
      'titleKey': 'module_title_announcements',
      'descriptionKey': 'module_description_announcements'
    },
    {
      'titleKey': 'module_title_market',
      'descriptionKey': 'module_description_market'
    },
    {
      'titleKey': 'module_title_wise_owl',
      'descriptionKey': 'module_description_wise_owl'
    },
    {
      'titleKey': 'module_title_games',
      'descriptionKey': 'module_description_games'
    },
    {
      'titleKey': 'module_title_digital_board',
      'descriptionKey': 'module_description_digital_board'
    },
    {
      'titleKey': 'module_title_documents',
      'descriptionKey': 'module_description_documents'
    },
    {
      'titleKey': 'module_title_repair',
      'descriptionKey': 'module_description_repair'
    },
    {
      'titleKey': 'module_title_commute',
      'descriptionKey': 'module_description_commute'
    },
    {
      'titleKey': 'module_title_security',
      'descriptionKey': 'module_description_security'
    },
    {
      'titleKey': 'module_title_alarm',
      'descriptionKey': 'module_description_alarm'
    },
    {
      'titleKey': 'module_title_social',
      'descriptionKey': 'module_description_social'
    },
    {
      'titleKey': 'module_title_services',
      'descriptionKey': 'module_description_services'
    },
  ];

  final List<String> _defaultImages = [
    'assets/images/locations/location1.png',
    'assets/images/locations/location2.png',
    'assets/images/locations/location3.png',
    'assets/images/locations/location4.png',
    'assets/images/locations/location5.png',
    'assets/images/locations/location6.png',
    'assets/images/locations/location7.png',
    'assets/images/locations/location8.png',
    'assets/images/locations/location9.png',
  ];

  Map<String, Map<String, int>> newContentCounts = {};
  bool _hasActiveRepairRequests = false;
  bool _dialogShown = false; // Flag da ne bi se dialog višestruko prikazivao

  @override
  void initState() {
    super.initState();
    _determineUserLocation();
    _fetchUserLocations();
    _checkUserType();
    _checkAffiliateStatus();

    _moduleSwitchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentModuleIndex = (_currentModuleIndex + 1) % _modules.length;
      });
    });
  }

  @override
  void dispose() {
    _moduleSwitchTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveRepairRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _hasActiveRepairRequests = false;
      });
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
      setState(() {
        _hasActiveRepairRequests = activeRepairsSnapshot.docs.isNotEmpty;
      });

      _logger.i('Korisnik ima aktivne popravke: $_hasActiveRepairRequests');
    } catch (e) {
      _logger.e('Error checking active repair requests: $e');
      if (!mounted) return;
      setState(() {
        _hasActiveRepairRequests = false;
      });
    }
  }

  Future<void> _determineUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
    }

    Position locationData = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final geoData = await _locationService.getGeographicalData(
      locationData.latitude,
      locationData.longitude,
    );

    if (!mounted) return;
    setState(() {
      _geoLocalCountryId = geoData['country'] ?? 'Unknown';
      _geoLocalCityId = geoData['city'] ?? 'Unknown';
    });

    _logger
        .i('Geo location country: $_geoLocalCountryId, city: $_geoLocalCityId');
    _fetchGeoNewPostsCount();
  }

  Future<void> _fetchGeoNewPostsCount() async {
    DateTime last24h = DateTime.now().subtract(const Duration(hours: 24));

    try {
      int postCount = await FirebaseFirestore.instance
          .collectionGroup(
              'posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}')
          .where('city', isEqualTo: _geoLocalCityId)
          .where('createdAt', isGreaterThanOrEqualTo: last24h)
          .get()
          .then((snapshot) => snapshot.size);

      if (mounted) {
        setState(() {});
      }

      _logger.i(
          "Fetched new posts count for local city $_geoLocalCityId: $postCount");
    } catch (e) {
      _logger.e('Error fetching geo new posts count: $e');
    }
  }

  /// provjeri u Firestoreu je li user affiliateActive
  Future<void> _checkAffiliateStatus() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    setState(() {
      _affiliateActive = doc.data()?['affiliateActive'] as bool? ?? false;
    });
  }

  Future<void> _fetchUserLocations() async {
    _logger.d('Fetching user locations...');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _logger.d('User is logged in: ${user.uid}');

      try {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(user.uid)
            .collection('locations')
            .where('deleted', isEqualTo: false)
            .where('status', whereIn: ['joined', 'pending']).get();

        if (snapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> filteredLocations = [];

          for (var locationDoc in snapshot.docs) {
            var location = locationDoc.data() as Map<String, dynamic>;

            // Dohvat podataka iz glavne "locations" kolekcije
            final locationDataSnapshot = await FirebaseFirestore.instance
                .collection('locations')
                .doc(location['locationId'])
                .get();

            if (locationDataSnapshot.exists) {
              Map<String, dynamic> realLocData = locationDataSnapshot.data()!;

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
                'imagePath': realLocData['imagePath'] ?? '',
              };
              filteredLocations.add(combinedLocation);
            } else {
              _logger.d(
                  'Location does not exist in the database: ${location['locationId']}');
            }
          }

          if (!mounted) return;
          setState(() {
            userLocations = filteredLocations;
            _logger.d('User locations updated: $userLocations');

            // Ako je pronađena samo 1 lokacija, odmah navigiramo
            if (userLocations.length == 1) {
              _logger.d('One location found, navigating to details...');
              _navigateToLocation(userLocations[0]);
            }
          });

          await _precacheLocationImages();
          await _fetchAllNewContentCounts();
          await _checkActiveRepairRequests();
        } else {
          _logger.w('No user locations found.');
          if (!mounted) return;
          setState(() {
            userLocations = [];
          });
          await _checkActiveRepairRequests();
          // Ako nema lokacija, pokaži dialog
          if (!_dialogShown) {
            _dialogShown = true;
            Future.delayed(Duration.zero, () => _showNoLocationsDialog())
                .then((_) {
              _dialogShown = false;
            });
          }
        }
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
      String imagePath = location['imagePath'] ?? _defaultImages[0];
      try {
        if (isNetworkImage(imagePath)) {
          await precacheImage(NetworkImage(imagePath), context);
        } else {
          await precacheImage(
            AssetImage(imagePath.isNotEmpty ? imagePath : _defaultImages[0]),
            context,
          );
        }
      } catch (e) {
        _logger.e('Error pre-caching image: $e');
      }
    }
    _logger.d('All location images have been pre-cached.');
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
            isFunnyMode: false,
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
            _isServicer = userData.data()?['userType'] == 'servicer';
            // ispravno postavi affiliate status
            _affiliateActive =
                userData.data()?['affiliateActive'] as bool? ?? false;
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
      _logger.w('No user is logged in');
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
        _logger.e('Servicer data not found for user: ${user.uid}');
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

      final servicerData = servicerDoc.data();
      final workingCountry = servicerData?['workingCountry'] ?? '';
      final workingCity = servicerData?['workingCity'] ?? '';

      if (workingCountry.isEmpty || workingCity.isEmpty) {
        _logger.e(
            'workingCountry ili workingCity nisu postavljeni za servicer: ${user.uid}');
        final loc = Provider.of<LocalizationService>(context, listen: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('servicerLocationNotSet') ??
                  'Radna lokacija nije postavljena za servisera.'),
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
      _logger.e('Error navigating to ServicerDashboardScreen: $e');
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

  bool isNetworkImage(String path) {
    return path.startsWith('http');
  }

  /// Funkcija s opcionalnim trailing widgetom (npr. animirani "free")
  Widget _buildCustomButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color buttonColor,
    Color textColor = Colors.white,
    double buttonHeight = 60,
    double iconSize = 28,
    double fontSize = 18,
    bool isBold = false,
    Widget? trailing,
  }) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: iconSize, color: textColor),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: textColor,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              backgroundColor: buttonColor,
            ),
          ),
        ),
        if (label ==
                (Provider.of<LocalizationService>(context, listen: false)
                        .translate('homeRepairs') ??
                    'Kućanski popravci') &&
            _hasActiveRepairRequests)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  /// Ovdje smo wrapali Column u ConstrainedBox + SingleChildScrollView
  /// kako bismo izbjegli overflow pri prikazu dugih tekstova.
  Widget _buildModuleDisplay() {
    final loc = Provider.of<LocalizationService>(context, listen: false);

    // Dohvat trenutnog modula
    final moduleTitle =
        loc.translate(_modules[_currentModuleIndex]['titleKey']!);
    final moduleDesc =
        loc.translate(_modules[_currentModuleIndex]['descriptionKey']!);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _modules.isNotEmpty
          ? ConstrainedBox(
              key: ValueKey<int>(_currentModuleIndex),
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      moduleTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      moduleDesc,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Text(
              loc.translate('noModulesAvailable') ?? 'Nema dostupnih modula.',
              style: const TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildEmptyOrLoadingState() {
    final loc = Provider.of<LocalizationService>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/conexa_user_loc_home_bg_1.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalH = constraints.maxHeight;
            final sectionH = totalH * 0.3; // 30% za gornju i donju sekciju

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  // Gornjih 30% visine: animirani modul
                  SizedBox(
                    height: sectionH,
                    child: Center(child: _buildModuleDisplay()),
                  ),

                  // Spacer
                  const Expanded(child: SizedBox.shrink()),

                  // Donjih 30% visine: skup gumba s originalnom logikom
                  SizedBox(
                    height: sectionH,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Kućanski popravci
                        _buildCustomButton(
                          label: loc.translate('homeRepairs') ??
                              'Kućanski popravci',
                          icon: Icons.build,
                          buttonColor: Colors.red,
                          fontSize: 16,
                          isBold: true,
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('userNotLoggedIn') ??
                                        'Korisnik nije prijavljen.',
                                  ),
                                ),
                              );
                              return;
                            }

                            String countryId = '';
                            String cityId = '';
                            String locationId = '';

                            if (userLocations.isNotEmpty) {
                              final loc0 = userLocations[0];
                              countryId = loc0['countryId'] ?? '';
                              cityId = loc0['cityId'] ?? '';
                              locationId = loc0['locationId'] ?? '';
                            } else {
                              try {
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .get();
                                if (userDoc.exists) {
                                  final data = userDoc.data()!;
                                  countryId = data['geoCountryId'] ?? '';
                                  cityId = data['geoCityId'] ?? '';
                                }
                              } catch (e) {
                                _logger.e('Error fetching user geo data: $e');
                              }
                            }

                            if (countryId == 'HR' ||
                                countryId.toLowerCase() == 'croatia') {
                              countryId = 'Hrvatska';
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportIssueScreen(
                                  username: widget.username,
                                  countryId: countryId,
                                  cityId: cityId,
                                  locationId: locationId,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) _checkActiveRepairRequests();
                            });
                          },
                        ),

                        const SizedBox(height: 6),

                        // Kreiraj lokaciju
                        _buildCustomButton(
                          label: loc.translate('createLocation') ??
                              'Kreiraj lokaciju',
                          icon: Icons.add_location_alt_outlined,
                          buttonColor: Colors.green,
                          buttonHeight: 42,
                          iconSize: 20,
                          fontSize: 14,
                          trailing: PulsatingBadge(
                            text: loc.translate('free') ?? 'free',
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateLocationScreen(
                                  username: widget.username,
                                  countryId: '',
                                  cityId: '',
                                  locationId: '',
                                ),
                              ),
                            ).then((_) {
                              if (mounted) _fetchUserLocations();
                            });
                          },
                        ),

                        const SizedBox(height: 6),

                        // Pridruži se lokaciji
                        _buildCustomButton(
                          label: loc.translate('joinLocation') ??
                              'Pridruži se lokaciji',
                          icon: Icons.group_add_outlined,
                          buttonColor: Colors.blue,
                          buttonHeight: 42,
                          iconSize: 20,
                          fontSize: 14,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const JoinLocationScreen()),
                            ).then((_) {
                              if (mounted) _fetchUserLocations();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(IconData icon, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    return ListView.builder(
      itemCount: userLocations.length,
      itemBuilder: (context, index) {
        final location = userLocations[index];
        String imagePath = (location['imagePath'] != null &&
                location['imagePath'].toString().trim().isNotEmpty)
            ? location['imagePath']
            : _defaultImages[0];

        bool isNetwork = imagePath.startsWith('http');

        return GestureDetector(
          onTap: () => _navigateToLocation(location),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                isNetwork
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.cover,
                        height: 240,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          _logger.e('Error loading network image: $error');
                          return Image.asset(
                            _defaultImages[0],
                            fit: BoxFit.cover,
                            height: 240,
                            width: double.infinity,
                          );
                        },
                      )
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        height: 240,
                        width: double.infinity,
                      ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Text(
                    '${location['cityId'] ?? Provider.of<LocalizationService>(context, listen: false).translate('unknownCity')}, ${location['countryId'] ?? Provider.of<LocalizationService>(context, listen: false).translate('unknownCountry')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      location['locationName'] ??
                          Provider.of<LocalizationService>(context,
                                  listen: false)
                              .translate('unknownLocation'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (newContentCounts.containsKey(location['locationId']))
                  Positioned(
                    bottom: 60,
                    right: 8,
                    child: Column(
                      children: [
                        if (newContentCounts[location['locationId']]!['chat']! >
                            0)
                          _buildIconWithBadge(
                              Icons.chat,
                              newContentCounts[location['locationId']]![
                                  'chat']!),
                        if (newContentCounts[location['locationId']]![
                                'officialNotices']! >
                            0)
                          _buildIconWithBadge(
                              Icons.campaign,
                              newContentCounts[location['locationId']]![
                                  'officialNotices']!),
                        if (newContentCounts[location['locationId']]![
                                'bulletinBoard']! >
                            0)
                          _buildIconWithBadge(
                              Icons.announcement,
                              newContentCounts[location['locationId']]![
                                  'bulletinBoard']!),
                        if (newContentCounts[location['locationId']]![
                                'documents']! >
                            0)
                          _buildIconWithBadge(
                              Icons.description,
                              newContentCounts[location['locationId']]![
                                  'documents']!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationsListWithButtons() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchUserLocations();
            },
            child: _buildLocationsList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _buildCustomButton(
                label: Provider.of<LocalizationService>(context, listen: false)
                        .translate('homeRepairs') ??
                    'Kućanski popravci',
                icon: Icons.build,
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    final loc = Provider.of<LocalizationService>(context,
                        listen: false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.translate('userNotLoggedIn') ??
                            'Korisnik nije prijavljen.'),
                      ),
                    );
                    return;
                  }

                  String countryId = '';
                  String cityId = '';
                  String locationId = '';

                  if (userLocations.isNotEmpty) {
                    final location = userLocations[0];
                    countryId = location['countryId'] ?? '';
                    cityId = location['cityId'] ?? '';
                    locationId = location['locationId'] ?? '';
                  } else {
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();

                      if (userDoc.exists) {
                        final userData = userDoc.data()!;
                        countryId = userData['geoCountryId'] ?? '';
                        cityId = userData['geoCityId'] ?? '';
                      }
                    } catch (e) {
                      _logger.e('Error fetching user geo data: $e');
                    }
                  }

                  if (countryId == 'HR' ||
                      countryId.toLowerCase() == 'croatia') {
                    countryId = 'Hrvatska';
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportIssueScreen(
                        username: widget.username,
                        countryId: countryId,
                        cityId: cityId,
                        locationId: locationId,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _checkActiveRepairRequests();
                    }
                  });
                },
                buttonColor: Colors.red,
                fontSize: 16,
                isBold: true,
              ),
              const SizedBox(height: 8),
              _buildCustomButton(
                label: Provider.of<LocalizationService>(context, listen: false)
                        .translate('createLocation') ??
                    'Kreiraj lokaciju',
                icon: Icons.add_location_alt_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateLocationScreen(
                        username: widget.username,
                        countryId: '',
                        cityId: '',
                        locationId: '',
                      ),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _fetchUserLocations();
                    }
                  });
                },
                buttonColor: Colors.green,
                buttonHeight: 42,
                iconSize: 20,
                fontSize: 14,
                trailing: PulsatingBadge(
                  text: Provider.of<LocalizationService>(context, listen: false)
                          .translate('free') ??
                      'free',
                ),
              ),
              const SizedBox(height: 6),
              _buildCustomButton(
                label: Provider.of<LocalizationService>(context, listen: false)
                        .translate('joinLocation') ??
                    'Pridruži se lokaciji',
                icon: Icons.group_add_outlined,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JoinLocationScreen(),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _fetchUserLocations();
                    }
                  });
                },
                buttonColor: Colors.blue,
                buttonHeight: 42,
                iconSize: 20,
                fontSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('conexaLife') ?? 'CONEXA.life',
          style: const TextStyle(fontSize: 20),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_isServicer)
            IconButton(
              icon: const Icon(Icons.build, color: Colors.orange),
              onPressed: _navigateToServicerDashboard,
              tooltip:
                  loc.translate('servicerDashboard') ?? 'Servicer Dashboard',
            ),
          IconButton(
            icon: const Icon(Icons.handshake, color: Colors.orange),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        // ako je već partner, bez lokacija → uđi u dashboard
                        if (_affiliateActive)
                          ListTile(
                            leading: const Icon(Icons.dashboard,
                                color: Colors.orange),
                            title: Text(loc.translate('affiliate_dashboard') ??
                                'Moj partnerski pregled'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AffiliateDashboardScreen()),
                              );
                            },
                          ),

                        // ako još nisi partner → vodi na registraciju partnera
                        if (!_affiliateActive)
                          ListTile(
                            leading: const Icon(Icons.handshake,
                                color: Colors.orange),
                            title: Text(
                                loc.translate('affiliate_new_registration') ??
                                    'Postani partner'),
                            onTap: () {
                              Navigator.pop(context);
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                // već je prijavljen → direktno na supplement screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AffiliateSupplementScreen(
                                        userId: user.uid),
                                  ),
                                );
                              } else {
                                // iznimno, ako ipak nije prijavljen → na login screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AffiliateExistingLoginScreen(),
                                  ),
                                );
                              }
                            },
                          ),

                        // postojeće stavke
                        ListTile(
                          leading:
                              const Icon(Icons.build, color: Colors.orange),
                          title: Text(loc.translate('registerServicer') ??
                              'Registriraj SERVIS'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewServicerRegistrationScreen(
                                  username: widget.username,
                                  countryId: '',
                                  cityId: '',
                                  locationId: '',
                                ),
                              ),
                            ).then((_) {
                              if (mounted) _checkActiveRepairRequests();
                            });
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.campaign, color: Colors.orange),
                          title: Text(
                              loc.translate('advertising') ?? 'Oglašavanje'),
                          onTap: () {
                            String adjustedCountryId = _geoLocalCountryId;
                            if (adjustedCountryId == 'HR' ||
                                adjustedCountryId.toLowerCase() == 'croatia' ||
                                adjustedCountryId.toLowerCase() == 'hr') {
                              adjustedCountryId = 'Hrvatska';
                            }
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdvertsInfoScreen(
                                  username: widget.username,
                                  countryId: adjustedCountryId,
                                  cityId: _geoLocalCityId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            tooltip: loc.translate('manageOptions') ?? 'Opcije za rukovanje',
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.apartment, size: 28, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocalHomeScreen(
                      username: widget.username,
                      locationAdmin: false,
                    ),
                  ),
                ).then((_) {
                  if (mounted) {
                    _fetchUserLocations();
                  }
                });
              },
              tooltip: loc.translate('localHome') ?? 'Local Home',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    username: widget.username,
                    countryId: '',
                    cityId: '',
                    locationId: '',
                    locationAdmin: false,
                  ),
                ),
              ).then((_) {
                if (mounted) {
                  _checkActiveRepairRequests();
                }
              });
            },
            tooltip: loc.translate('settings') ?? 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline,
                color: Color.fromARGB(255, 132, 162, 196)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(
                    onFinish: () => Navigator.pop(context),
                    onSkip: () => Navigator.pop(context),
                  ),
                ),
              );
            },
            tooltip: loc.translate('appInfo') ?? 'App Info',
          ),
        ],
      ),
      body: userLocations.isEmpty
          ? _buildEmptyOrLoadingState()
          : _buildLocationsListWithButtons(),
    );
  }
}

/// Widget za pulsirajuću oznaku (badge) koja prikazuje tekst "free"
class PulsatingBadge extends StatefulWidget {
  final String text;
  const PulsatingBadge({super.key, required this.text});

  @override
  _PulsatingBadgeState createState() => _PulsatingBadgeState();
}

class _PulsatingBadgeState extends State<PulsatingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SizedBox(
        height: 20, // prilagodite visinu prema potrebama
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Jednostavan dialog za unos poruke (ako korisnik nije ulogiran)
class SimpleHelpDialog extends StatefulWidget {
  const SimpleHelpDialog({super.key});

  @override
  _SimpleHelpDialogState createState() => _SimpleHelpDialogState();
}

class _SimpleHelpDialogState extends State<SimpleHelpDialog> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _isSending = false;
  final Logger _logger = Logger();

  Future<void> _sendFeedback() async {
    final String message = _messageController.text;
    final String? name =
        _nameController.text.isNotEmpty ? _nameController.text : null;
    final String? contact =
        _contactController.text.isNotEmpty ? _contactController.text : null;

    if (message.isEmpty) {
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('message_cannot_be_empty')),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await FirebaseFirestore.instance.collection('voxpopuli_hr').add({
        'message': message,
        'name': name,
        'contact': contact,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'profilePic': FirebaseAuth.instance.currentUser?.photoURL,
      });

      _messageController.clear();
      _nameController.clear();
      _contactController.clear();

      final loc = Provider.of<LocalizationService>(context, listen: false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(loc.translate('thank_you')),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Text(loc.translate('message_sent_successfully')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.translate('error_sending_email')} $e'),
        ),
      );
      _logger.e("Feedback send failed: $e");
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return AlertDialog(
      title: Text(loc.translate('request_help')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: loc.translate('enter_your_message'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.translate('name_optional'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: loc.translate('contact_optional'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : _sendFeedback,
          child: _isSending
              ? const CircularProgressIndicator()
              : Text(loc.translate('send')),
        ),
      ],
    );
  }
}

/// Placeholder za VideoScreen – otvara YouTube Shorts URL preko _launchURL.
class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('video')),
      ),
      body: Center(
        child: Text(loc.translate('video_placeholder')),
      ),
    );
  }
}
