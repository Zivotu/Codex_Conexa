import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'affiliate_dashboard_screen.dart';

// Uvezite svoje servise i ekrane
import '../services/location_service.dart';
import 'package:conexa/local/services/post_service.dart';
import 'location_settings_screen.dart';
import 'classic_mode.dart' as classic;
import 'funny_mode.dart'; // Ako koristite FunnyMode, inače NewsPortalView.
import 'package:conexa/local/screens/local_home_screen.dart';
import 'user_locations_screen.dart';
import 'join_location_screen.dart';
import 'create_location_screen.dart';
import 'new_servicer_registration_screen.dart';
import 'adverts_info_screen.dart';
import 'servicer_dashboard_screen.dart';
import '../services/localization_service.dart';
import 'settings_edit_profile_screen.dart';
import 'news_portal_view.dart';

/// Custom AppBar s gradijentnom pozadinom i zaobljenim donjim rubom.
AppBar buildCustomAppBar(
  String title,
  VoidCallback onMenuPressed,
  Widget actionWidget,
) {
  return AppBar(
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
    ),
    elevation: 10,
    centerTitle: true,
    title: Text(
      title,
      style: GoogleFonts.lato(
        textStyle: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    leading: Tooltip(
      message: 'Menu',
      waitDuration: Duration.zero,
      child: IconButton(
        icon: const Icon(Icons.menu, size: 35, color: Colors.white),
        onPressed: onMenuPressed,
      ),
    ),
    actions: [
      Padding(padding: const EdgeInsets.only(right: 8.0), child: actionWidget),
    ],
  );
}

/// KeepAliveWrapper – osigurava da se sadržaj učita jednom i ostane u memoriji.
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class LocationDetailsScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;
  final String displayName;
  final bool
      isFunnyMode; // Ako je true, koristi se FunnyMode, inače NewsPortalView.
  final bool locationAdmin;

  const LocationDetailsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
    required this.displayName,
    required this.isFunnyMode,
    required this.locationAdmin,
  });

  @override
  LocationDetailsScreenState createState() => LocationDetailsScreenState();
}

class LocationDetailsScreenState extends State<LocationDetailsScreen> {
  late String _username;
  String locationName = '';
  int newPostsCount = 0;
  String profileImageUrl = '';
  int _cityPostsCount = 0;
  String _geoLocalCityId = 'Unknown';
  final LocationService locationService = LocationService();
  final PostService postService = PostService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Logger _logger = Logger();
  bool _isServicer = false;
  bool _isAffiliatePartner = false;

  // PageController – učitava zadnji aktivan mod (0 = Classic, 1 = News/Funny)
  late PageController _pageController;
  int _currentPage = 0;
  bool _newsRevealed = false;

  // NOVA VARIJABLA: spremi aktivnu (nepročitanu) poruku
  DocumentSnapshot? activeMessage;
  // Oznaka je li poruka pročitana danas
  bool _messageReadToday = false;

  @override
  void initState() {
    super.initState();
    _username = widget.username;
    _loadLastMode().then((initialPage) {
      _currentPage = initialPage;
      _pageController = PageController(initialPage: initialPage);
      setState(() {});
    });
    _determineUserLocation();
    _fetchData();
    _checkUserType();
    Provider.of<LocalizationService>(context, listen: false).init();
    // Dohvati poruku samo jednom prilikom otvaranja ekrana
    _fetchActiveMessage();
    _checkIfAffiliatePartner();
  }

  Future<int> _loadLastMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_mode') ?? 0;
  }

  Future<void> _saveLastMode(int mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mode', mode);
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
    final geoData = await locationService.getGeographicalData(
      locationData.latitude,
      locationData.longitude,
    );
    setState(() {
      _geoLocalCityId = geoData['city'] ?? 'Unknown';
    });
    _fetchGeoNewPostsCount();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchLocationName(),
      _fetchProfileImage(),
      _fetchNewPostsCount(),
    ]);
  }

  Future<void> _fetchLocationName() async {
    final locationDoc = await FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .get();
    if (locationDoc.exists && mounted) {
      setState(() {
        locationName = locationDoc.data()!['name'] ?? widget.displayName;
      });
    } else {
      _logger.w('Location document not found for ${widget.locationId}');
    }
  }

  Future<void> _fetchProfileImage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (userDoc.exists && mounted) {
      setState(() {
        profileImageUrl = userDoc.data()!['profileImageUrl'] ??
            'assets/images/default_user.png';
        _username = userDoc.data()!['username'] ?? 'UnknownUser';
      });
      _logger.i('Fetched user profile image and username: $_username');
    }
  }

  Future<void> _fetchGeoNewPostsCount() async {
    DateTime last24h = DateTime.now().subtract(const Duration(hours: 24));
    int postCount = await FirebaseFirestore.instance
        .collectionGroup(
          'posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}',
        )
        .where('city', isEqualTo: _geoLocalCityId)
        .where('createdAt', isGreaterThanOrEqualTo: last24h)
        .get()
        .then((snapshot) => snapshot.size);
    setState(() {
      _cityPostsCount = postCount;
    });
  }

  Future<void> _fetchNewPostsCount() async {
    DateTime last24h = DateTime.now().subtract(const Duration(hours: 24));
    int postCount = await FirebaseFirestore.instance
        .collectionGroup(
          'posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}',
        )
        .where('city', isEqualTo: widget.cityId)
        .where('createdAt', isGreaterThanOrEqualTo: last24h)
        .get()
        .then((snapshot) => snapshot.size);
    setState(() {
      newPostsCount = postCount;
    });
  }

  Future<void> _checkIfAffiliatePartner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('affiliate_bonus_codes')
        .where('userId', isEqualTo: user.uid)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      setState(() {
        _isAffiliatePartner = true;
      });
    }
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userData.exists) {
        setState(() {
          _isServicer = userData.data()!['userType'] == 'servicer';
        });
      }
    }
  }

  // NOVA FUNKCIJA: Dohvat aktivne poruke iz kolekcije "globalmessage" (bez filtera na 'active')
  Future<void> _fetchActiveMessage() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('globalmessage').get();
    if (snapshot.docs.isNotEmpty) {
      DocumentSnapshot messageDoc = snapshot.docs.first;
      bool isRead = await checkIfMessageIsRead(messageDoc.id);
      if (!isRead) {
        setState(() {
          activeMessage = messageDoc;
        });
      }
    }
  }

  Future<void> _navigateToServicerDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    if (user == null) {
      _logger.w('No user is logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('user_not_logged_in')),
        ),
      );
      return;
    }
    try {
      final servicerDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(user.uid)
          .get();
      if (!servicerDoc.exists) {
        _logger.e('Servicer data not found for user: ${user.uid}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizationService.translate('servicer_not_found')),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServicerDashboardScreen(username: _username),
        ),
      );
    } catch (e) {
      _logger.e('Error navigating to ServicerDashboardScreen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizationService.translate('error')}: $e'),
        ),
      );
    }
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _changeLanguage(String? languageCode) async {
    if (languageCode != null) {
      await Provider.of<LocalizationService>(
        context,
        listen: false,
      ).loadLanguage(languageCode);
      setState(() {});
    }
  }

  /// Pomoćna funkcija koja izračunava opacitet ikone na temelju starosti poruke.
  /// Ako je poruka stara 0 dana, opacitet je 1.0, a ako je stara 7 dana ili više, opacitet je 0.6.
  double _calculateOpacity(Timestamp createdAt) {
    DateTime creation = createdAt.toDate();
    Duration diff = DateTime.now().difference(creation);
    double days = diff.inDays.toDouble();
    if (days >= 7) {
      return 0.6;
    }
    return 1.0 - ((0.4 / 7) * days);
  }

  Widget _buildActivationStatusWidget() {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(localizationService.translate('error_loading_status'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;

        // Ako je superAllow aktivan, ne prikazuj status u draweru.
        if (data['superAllow'] == true) {
          return Container();
        }

        final String actType = data['activationType'] ?? 'inactive';
        final Timestamp? ts = data['activeUntil'];
        DateTime? locEnd = ts?.toDate();
        final now = DateTime.now();
        String statusText = "";
        TextStyle statusStyle = const TextStyle(
          color: Colors.black,
          fontSize: 16,
        );
        if (actType == 'active') {
          if (locEnd!.isAfter(now)) {
            final formattedDate =
                "${locEnd.day}.${locEnd.month}.${locEnd.year}";
            statusText =
                "${localizationService.translate('locationActive')} (do $formattedDate)";
          } else {
            statusText = localizationService.translate('subscriptionExpired');
            statusStyle = const TextStyle(color: Colors.red, fontSize: 16);
          }
        } else if (actType == 'trial') {
          if (locEnd!.isAfter(now)) {
            final formattedDate =
                "${locEnd.day}.${locEnd.month}.${locEnd.year}";
            statusText =
                "${localizationService.translate('trialActive')} $formattedDate";
            statusStyle = const TextStyle(color: Colors.orange, fontSize: 16);
          } else {
            statusText = localizationService.translate('trialExpired');
            statusStyle = const TextStyle(color: Colors.red, fontSize: 16);
          }
        } else if (actType == 'trialexpired') {
          statusText = localizationService.translate('trialExpired');
          statusStyle = const TextStyle(color: Colors.red, fontSize: 16);
        } else if (actType == 'manualdeactivated') {
          statusText = localizationService.translate(
            'locationManualDeactivated',
          );
          statusStyle = const TextStyle(color: Colors.red, fontSize: 16);
        } else {
          statusText = localizationService.translate('locationInactive');
          statusStyle = const TextStyle(color: Colors.red, fontSize: 16);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(statusText, style: statusStyle),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    int postCount = 0,
    Color? backgroundColor,
    TextStyle? textStyle,
    Color? iconColor,
  }) {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    return Container(
      color: backgroundColor,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: textStyle),
            if (text == localizationService.translate('neighborhood'))
              Row(
                children: [
                  if (postCount > 0)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$postCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      localizationService.translate('hours_24'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: true,
    );
    return Scaffold(
      key: _scaffoldKey,
      appBar: buildCustomAppBar(
        locationName,
        () => _scaffoldKey.currentState?.openDrawer(),
        // Prikaz poruke: ikonica s opacitetom, a ako je poruka pročitana danas, prikazuje se kvačica.
        activeMessage != null
            ? Opacity(
                opacity: _calculateOpacity(
                  activeMessage!.get('createdAt') as Timestamp,
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.mark_email_unread,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        showMessageDialog(context, activeMessage!);
                        // Kada korisnik otvori poruku, označavamo da ju je pročitao danas
                        setState(() {
                          _messageReadToday = true;
                        });
                      },
                    ),
                    if (_messageReadToday)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(Icons.check, size: 16, color: Colors.green),
                      ),
                  ],
                ),
              )
            : Container(),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // DrawerHeader – ovdje nema promjena
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF3949AB)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    content: Image(
                                      image: profileImageUrl.isNotEmpty
                                          ? (profileImageUrl.startsWith(
                                              'http',
                                            )
                                              ? NetworkImage(
                                                  profileImageUrl,
                                                )
                                              : AssetImage(
                                                  profileImageUrl,
                                                ) as ImageProvider)
                                          : const AssetImage(
                                              'assets/images/default_user.png',
                                            ),
                                      fit: BoxFit.cover,
                                      height: 300,
                                      width: 300,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Image.asset(
                                          'assets/images/default_user.png',
                                          fit: BoxFit.cover,
                                          height: 300,
                                          width: 300,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 25,
                                backgroundImage: profileImageUrl.isNotEmpty
                                    ? (profileImageUrl.startsWith('http')
                                        ? NetworkImage(profileImageUrl)
                                        : AssetImage(profileImageUrl)
                                            as ImageProvider)
                                    : const AssetImage(
                                        'assets/images/default_user.png',
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Tooltip(
                            message:
                                localizationService.translate('home') ?? 'Home',
                            waitDuration: Duration.zero,
                            child: IconButton(
                              icon: const Icon(
                                Icons.home,
                                size: 35,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserLocationsScreen(
                                      username: _username,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isServicer)
                            Tooltip(
                              message: localizationService.translate(
                                    'servicer_dashboard',
                                  ) ??
                                  'Servicer Dashboard',
                              waitDuration: Duration.zero,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.build,
                                  size: 35,
                                  color: Colors.orange,
                                ),
                                onPressed: _navigateToServicerDashboard,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _buildActivationStatusWidget(),
            ),
            _buildDrawerItem(
              icon: Icons.location_city,
              text: localizationService.translate('neighborhood'),
              onTap: () {
                _navigateToScreen(
                  LocalHomeScreen(username: _username, locationAdmin: true),
                );
              },
              postCount: _cityPostsCount,
              backgroundColor: Colors.blue[100],
              textStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.add_location,
              text: localizationService.translate('create_location'),
              onTap: () {
                _navigateToScreen(
                  CreateLocationScreen(
                    username: _username,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                );
              },
              backgroundColor: Colors.green,
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              iconColor: Colors.white,
            ),
            _buildDrawerItem(
              icon: Icons.add_circle_outline,
              text: localizationService.translate('join_location'),
              onTap: () {
                _navigateToScreen(const JoinLocationScreen());
              },
            ),
            _buildDrawerItem(
              icon: Icons.settings,
              text: localizationService.translate('location_settings'),
              onTap: () {
                _navigateToScreen(
                  LocationSettingsScreen(
                    username: _username,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                    locationAdmin: widget.locationAdmin,
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.account_circle,
              text: localizationService.translate('profile_settings'),
              onTap: () {
                _navigateToScreen(
                  SettingsEditProfileScreen(
                    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                );
              },
            ),
            if (_isAffiliatePartner)
              _buildDrawerItem(
                icon: Icons.handshake,
                text: localizationService.translate('affiliate_dashboard'),
                onTap: () {
                  _navigateToScreen(const AffiliateDashboardScreen());
                },
                backgroundColor: Colors.deepPurple.shade100,
                textStyle: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
                iconColor: Colors.deepPurple,
              ),

            _buildDrawerItem(
              icon: Icons.logout,
              text: localizationService.translate('logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizationService.translate('select_language'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: Provider.of<LocalizationService>(
                      context,
                      listen: false,
                    ).currentLanguage,
                    isExpanded: true,
                    onChanged: _changeLanguage,
                    items: const [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text('🇬🇧 English'),
                      ),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text('🇸🇦 العربية'),
                      ),
                      DropdownMenuItem(value: 'bn', child: Text('🇧🇩 বাংলা')),
                      DropdownMenuItem(
                        value: 'bs',
                        child: Text('🇧🇦 Bosanski'),
                      ),
                      DropdownMenuItem(value: 'da', child: Text('🇩🇰 Dansk')),
                      DropdownMenuItem(
                        value: 'de',
                        child: Text('🇩🇪 Deutsch'),
                      ),
                      DropdownMenuItem(
                        value: 'es',
                        child: Text('🇪🇸 Español'),
                      ),
                      DropdownMenuItem(value: 'fa', child: Text('🇮🇷 فارسی')),
                      DropdownMenuItem(value: 'fi', child: Text('🇫🇮 Suomi')),
                      DropdownMenuItem(
                        value: 'fr',
                        child: Text('🇫🇷 Français'),
                      ),
                      DropdownMenuItem(value: 'hi', child: Text('🇮🇳 हिन्दी')),
                      DropdownMenuItem(
                        value: 'hr',
                        child: Text('🇭🇷 Hrvatski'),
                      ),
                      DropdownMenuItem(value: 'hu', child: Text('🇭🇺 Magyar')),
                      DropdownMenuItem(
                        value: 'id',
                        child: Text('🇮🇩 Bahasa Indonesia'),
                      ),
                      DropdownMenuItem(
                        value: 'is',
                        child: Text('🇮🇸 Íslenska'),
                      ),
                      DropdownMenuItem(
                        value: 'it',
                        child: Text('🇮🇹 Italiano'),
                      ),
                      DropdownMenuItem(value: 'ja', child: Text('🇯🇵 日本語')),
                      DropdownMenuItem(value: 'ko', child: Text('🇰🇷 한국어')),
                      DropdownMenuItem(
                        value: 'nl',
                        child: Text('🇳🇱 Nederlands'),
                      ),
                      DropdownMenuItem(value: 'no', child: Text('🇳🇴 Norsk')),
                      DropdownMenuItem(value: 'pl', child: Text('🇵🇱 Polski')),
                      DropdownMenuItem(
                        value: 'pt',
                        child: Text('🇵🇹 Português'),
                      ),
                      DropdownMenuItem(value: 'ro', child: Text('🇷🇴 Română')),
                      DropdownMenuItem(
                        value: 'ru',
                        child: Text('🇷🇺 Русский'),
                      ),
                      DropdownMenuItem(
                        value: 'sl',
                        child: Text('🇸🇮 Slovensko'),
                      ),
                      DropdownMenuItem(value: 'sr', child: Text('🇷🇸 Srpski')),
                      DropdownMenuItem(
                        value: 'sv',
                        child: Text('🇸🇪 Svenska'),
                      ),
                      DropdownMenuItem(value: 'th', child: Text('🇹🇭 ไทย')),
                      DropdownMenuItem(value: 'tr', child: Text('🇹🇷 Türkçe')),
                      DropdownMenuItem(
                        value: 'vi',
                        child: Text('🇻🇳 Tiếng Việt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      _navigateToScreen(
                        NewServicerRegistrationScreen(
                          username: _username,
                          countryId: widget.countryId,
                          cityId: widget.cityId,
                          locationId: widget.locationId,
                        ),
                      );
                    },
                    child: Text(
                      localizationService.translate('register_servicer'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _navigateToScreen(
                        AdvertsInfoScreen(
                          username: _username,
                          countryId: widget.countryId,
                          cityId: widget.cityId,
                        ),
                      );
                    },
                    child: Text(
                      localizationService.translate('advertising'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // PageView – koristi ClampingScrollPhysics i sprema zadnji aktivan mod.
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
          _saveLastMode(page);
        },
        children: [
          // Classic Mode
          KeepAliveWrapper(
            child: classic.ClassicMode(
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
              username: _username,
              locationAdmin: widget.locationAdmin,
            ),
          ),
          // News/Funny mod – s reveal animacijom koja se pokrene samo prvi put
          KeepAliveWrapper(
            child: Stack(
              children: [
                widget.isFunnyMode
                    ? FunnyMode(
                        countryId: widget.countryId,
                        cityId: widget.cityId,
                        locationId: widget.locationId,
                        username: _username,
                      )
                    : NewsPortalView(
                        countryId: widget.countryId,
                        cityId: widget.cityId,
                        locationId: widget.locationId,
                        username: _username,
                        locationAdmin: widget.locationAdmin,
                      ),
                if (!_newsRevealed)
                  SplitRevealOverlay(
                    onAnimationComplete: () {
                      setState(() {
                        _newsRevealed = true;
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SplitRevealOverlay – animirani overlay koji se otkriva prilikom ulaska u News mod.
class SplitRevealOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  const SplitRevealOverlay({super.key, required this.onAnimationComplete});

  @override
  _SplitRevealOverlayState createState() => _SplitRevealOverlayState();
}

class _SplitRevealOverlayState extends State<SplitRevealOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _topAnimation;
  late Animation<double> _bottomAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _topAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _bottomAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double topOffset = -_topAnimation.value * height;
            double bottomOffset = _bottomAnimation.value * height;
            return Stack(
              children: [
                Positioned(
                  top: topOffset,
                  left: 0,
                  right: 0,
                  height: height / 2,
                  child: Container(color: Colors.black),
                ),
                Positioned(
                  top: height / 2 + bottomOffset,
                  left: 0,
                  right: 0,
                  height: height / 2,
                  child: Container(color: Colors.black),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ----------------- Internal Messaging Helper Functions -----------------

Future<bool> checkIfMessageIsRead(String messageId) async {
  final prefs = await SharedPreferences.getInstance();
  String key =
      "message_${messageId}_${DateFormat('yyyyMMdd').format(DateTime.now())}_read";
  return prefs.getBool(key) ?? false;
}

Future<void> markMessageAsRead(String messageId) async {
  final prefs = await SharedPreferences.getInstance();
  String key =
      "message_${messageId}_${DateFormat('yyyyMMdd').format(DateTime.now())}_read";
  await prefs.setBool(key, true);
}

void showMessageDialog(BuildContext context, DocumentSnapshot messageDoc) {
  final localizationService = Provider.of<LocalizationService>(
    context,
    listen: false,
  );
  String userLang = localizationService.currentLanguage.toLowerCase();
  // Parsiramo JSON string iz polja 'text'
  Map<String, dynamic> translations = jsonDecode(messageDoc.get('text'));
  Map<String, dynamic> messageContent =
      translations[userLang] ?? translations['en'] ?? {};
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(messageContent['title'] ?? 'Obavijest'),
      content: Text(messageContent['body'] ?? 'Imate novu poruku.'),
      actions: [
        TextButton(
          onPressed: () {
            markMessageAsRead(messageDoc.id);
            // Označi da je poruka pročitana danas
            (context as Element)
                .markNeedsBuild(); // Trigger rebuild ako je potrebno
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
