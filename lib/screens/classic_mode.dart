import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/user_service.dart';
import '../services/localization_service.dart';
import '../models/repair_request.dart';
import 'voxpopuli.dart';
import 'package:get_it/get_it.dart';
import 'wise_owl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import '../screens/ad_detail_screen.dart';
import '../widgets/animated_category_card.dart';
import 'readings_screen.dart';
import '../commute_screens/commute_rides_list_screen.dart';
import 'snow_cleaning_screen.dart';
import 'admin_vox_populi_screen.dart';

/// Pomoćna metoda za dobivanje status detalja iz RepairRequest podataka.
Map<String, dynamic> getRepairStatusDetails(
  Map<String, dynamic> repair,
  LocalizationService localizationService,
) {
  String statusMessage = '';
  IconData statusIcon = Icons.info;
  Color statusColor = Colors.grey;

  final selectedTimeSlot = repair['selectedTimeSlot'];
  final servicerConfirmedTimeSlot = repair['servicerConfirmedTimeSlot'];
  final servicerOffers = repair['servicerOffers'] ?? [];

  if (repair['status'] == 'waitingforconfirmation') {
    statusMessage = localizationService.translate('waitingforconfirmation') ??
        localizationService.translate('waitingForConfirmationFallback') ??
        'Čekamo potvrdu termina.'; // Fallback
    statusIcon = Icons.hourglass_empty;
    statusColor = Colors.orangeAccent;
  } else if (repair['status'] == 'Published_2') {
    statusMessage = localizationService
            .translate('chooseServicerArrivalTime') ??
        localizationService.translate('chooseServicerArrivalTimeFallback') ??
        'Odaberite termin dolaska servisera.'; // Fallback
    statusIcon = Icons.schedule;
    statusColor = Colors.orange;
  } else if (servicerOffers.isNotEmpty && selectedTimeSlot == null) {
    statusMessage = localizationService.translate('selectTimeSlot') ??
        localizationService.translate('selectTimeSlotFallback') ??
        'Odaberite termin.'; // Fallback
    statusIcon = Icons.schedule;
    statusColor = Colors.orange;
  } else if (selectedTimeSlot != null && servicerConfirmedTimeSlot == null) {
    DateTime selectedDate = (selectedTimeSlot as Timestamp).toDate();
    String formattedDate =
        '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}. - '
        '${selectedDate.hour.toString().padLeft(2, '0')}:'
        '${selectedDate.minute.toString().padLeft(2, '0')}';

    final baseTranslation = localizationService
            .translate('waitingforconfirmationwithdate') ??
        'Čekamo potvrdu servisera za {date}.'; // generička poruka s placeholderom

    // Ako želiš umetnuti datum u poruku, možeš napraviti interpolaciju:
    statusMessage = baseTranslation.replaceAll('{date}', formattedDate);

    statusIcon = Icons.hourglass_empty;
    statusColor = Colors.orangeAccent;
  } else if (servicerConfirmedTimeSlot != null) {
    statusMessage = localizationService.translate('serviceConfirmed') ??
        'Servis dogovoren!'; // Fallback
    statusIcon = Icons.check_circle;
    statusColor = Colors.green;
  } else if (servicerOffers.isEmpty) {
    statusMessage = localizationService.translate('searchingForServicer') ??
        localizationService.translate('searchingForServicerFallback') ??
        'Tražimo servisera!'; // Fallback
    statusIcon = Icons.search;
    statusColor = Colors.blue;
  } else {
    statusMessage = localizationService.translate('unknownStatus') ??
        localizationService.translate('unknownStatusFallback') ??
        'Nepoznat status'; // Fallback
    statusIcon = Icons.help;
    statusColor = const Color.fromARGB(255, 108, 108, 108);
  }

  return {
    'message': statusMessage,
    'icon': statusIcon,
    'color': statusColor,
  };
}

class ClassicMode extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;
  final bool locationAdmin;

  const ClassicMode({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
    required this.locationAdmin,
  });

  @override
  ClassicModeState createState() => ClassicModeState();
}

class ClassicModeState extends State<ClassicMode>
    with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  String? locationName;
  String? displayName;
  List<Map<String, dynamic>> randomAds = [];
  bool isFunnyMode = false;

  late final Future<List<String>> _randomAdTitlesFuture;
  late final Future<String> _wiseOwlSubtitleFuture;

  Map<String, bool> _enabledModules = {};

  late AnimationController _initialAnimationController;
  late AnimationController _danceAnimationController;

  final ScrollController _scrollController = ScrollController();
  double _dragDistance = 0.0;
  bool _isDancing = false;
  bool _animateExit = false;

  @override
  void initState() {
    super.initState();

    _initialAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAnimationController.forward();
    });

    _danceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fetchLocationData();
    _fetchUserName();
    _fetchRandomAds();

    _randomAdTitlesFuture = _getRandomAdTitlesFuture();
    _wiseOwlSubtitleFuture = getNewDailySayingFuture();
  }

  @override
  void dispose() {
    _initialAnimationController.dispose();
    _danceAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> triggerExitAnimation() async {
    setState(() {
      _animateExit = true;
      _initialAnimationController.duration = const Duration(milliseconds: 1000);
      _initialAnimationController.reset();
    });
    await _initialAnimationController.forward();
  }

  Future<void> triggerEntranceAnimation() async {
    setState(() {
      _animateExit = false;
      _initialAnimationController.duration = const Duration(milliseconds: 1400);
      _initialAnimationController.reset();
    });
    await _initialAnimationController.forward();
  }

  void _triggerDanceAnimation() async {
    setState(() {
      _isDancing = true;
    });
    _danceAnimationController.reset();
    await _danceAnimationController.forward();
    setState(() {
      _isDancing = false;
    });
  }

  Future<void> _fetchLocationData() async {
    final doc = await FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['enabledModules'] != null) {
        final modulesData = data['enabledModules'] as Map<String, dynamic>;
        setState(() {
          _enabledModules = {
            'officialNotices': modulesData['officialNotices'] ?? true,
            'chatRoom': modulesData['chatRoom'] ?? true,
            'quiz': modulesData['quiz'] ?? true,
            'bulletinBoard': modulesData['bulletinBoard'] ?? true,
            'parkingCommunity': modulesData['parkingCommunity'] ?? true,
            'wiseOwl': modulesData['wiseOwl'] ?? true,
            'snowCleaning': modulesData['snowCleaning'] ?? true,
            'security': modulesData['security'] ?? true,
            'alarm': modulesData['alarm'] ?? true,
            'noise': modulesData['noise'] ?? true,
            'readings': modulesData['readings'] ?? true,
          };
        });
      }
    }

    final locationData = await _locationService.getLocationDocument(
      widget.countryId,
      widget.cityId,
      widget.locationId,
    );
    if (locationData != null && locationData['name'] != null) {
      setState(() {
        locationName = locationData['name'];
      });
    }
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _userService.getUserDocument(user);
      if (userData != null && userData['displayName'] != null) {
        setState(() {
          displayName = userData['displayName'];
        });
      }
    }
  }

  Future<void> _fetchRandomAds() async {
    try {
      final currentDate = DateTime.now();
      final adQuery = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('ads')
          .get();

      final ads = adQuery.docs.map((doc) => doc.data()).where((data) {
        if (data['endDate'] != null) {
          final endDate = (data['endDate'] as Timestamp).toDate();
          return endDate.isAfter(currentDate);
        }
        return false;
      }).toList();

      if (ads.isNotEmpty) {
        ads.shuffle();
        setState(() {
          randomAds = ads.take(2).toList();
        });
      } else {
        final localizationService =
            Provider.of<LocalizationService>(context, listen: false);
        setState(() {
          randomAds = [];
          debugPrint(localizationService.translate('noActiveAdsFound') ??
              localizationService.translate('noActiveAdsFoundFallback') ??
              'No Active Ads Found');
        });
      }
    } catch (e) {
      debugPrint('Error fetching ads: $e');
    }
  }

  Future<List<String>> _getRandomAdTitlesFuture() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final currentDate = DateTime.now();
      final adQuery = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('ads')
          .where('ended', isEqualTo: false)
          .get();
      debugPrint('Ads query found ${adQuery.docs.length} documents.');

      final ads = adQuery.docs
          .map((doc) => doc.data())
          .where((data) {
            if (data['endDate'] != null) {
              final endDate = (data['endDate'] as Timestamp).toDate();
              return endDate.isAfter(currentDate);
            }
            return false;
          })
          .map((data) => data['title'] as String?)
          .whereType<String>()
          .toList();

      debugPrint('Filtered active ads count: ${ads.length}');
      if (ads.isNotEmpty) {
        ads.shuffle();
        return ads.take(3).toList();
      } else {
        debugPrint(localizationService.translate('noActiveAdsFound') ??
            localizationService.translate('noActiveAdsFoundFallback') ??
            'No Active Ads Found');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching random ad titles: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchRepairRequestStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return {};

      final repairRequestsSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('repair_requests')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            'Published',
            'In Negotiation',
            'Job Agreed',
            'waitingforconfirmation',
            'Published_2',
          ])
          .orderBy('requestedDate', descending: true)
          .limit(1)
          .get();

      if (repairRequestsSnapshot.docs.isEmpty) {
        return {'status': 'No Active Repairs'};
      }

      final repairData = repairRequestsSnapshot.docs.first.data();
      return repairData;
    } catch (e) {
      debugPrint("Error fetching repair status: $e");
      return {'status': 'Error'};
    }
  }

  Future<List<String>> _fetchPlayersWhoPlayedToday() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final todayDate = DateTime.now().toIso8601String().substring(0, 10);
      final snapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('quizz')
          .doc(todayDate)
          .collection('results')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final username = data['username'] as String? ??
            (localizationService.translate('anonymous') ?? 'Anonimus');
        final score = data['score'] != null ? data['score'].toString() : '0';
        return '$username($score)';
      }).toList();
    } catch (e) {
      debugPrint('Error fetching players who played today: $e');
      return [];
    }
  }

  Future<String> _fetchNearestWorks() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final constructionsCollection = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('constructions');

      final querySnapshot = await constructionsCollection.get();
      DateTime today = DateTime.now();
      List<Map<String, dynamic>> upcomingWorks = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> work = doc.data();
        DateTime startDate = DateTime.parse(work['startDate']);
        DateTime endDate = DateTime.parse(work['endDate']);

        if (endDate.isAfter(today)) {
          upcomingWorks.add({
            'startDate': startDate,
            'endDate': endDate,
          });
        }
      }

      if (upcomingWorks.isEmpty) {
        return localizationService.translate('noUpcomingWorks') ??
            'Nema nadolazećih radova';
      }

      upcomingWorks.sort((a, b) =>
          (a['startDate'] as DateTime).compareTo(b['startDate'] as DateTime));

      var nearestWork = upcomingWorks.first;
      DateTime start = nearestWork['startDate'];
      DateTime end = nearestWork['endDate'];

      String formattedStart = '${start.day}.${start.month}.';
      String formattedEnd = '${end.day}.${end.month}.';
      return '$formattedStart – $formattedEnd';
    } catch (e) {
      debugPrint(
          "${localizationService.translate('errorFetchingWorks') ?? 'Greška pri dohvaćanju radova'}: $e");
      return localizationService.translate('errorFetchingWorks') ??
          'Greška pri dohvaćanju radova';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSnowCleaningSchedule() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return [];

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('snow_cleaning_schedules')
          .doc(widget.locationId)
          .get();

      if (!scheduleDoc.exists) {
        debugPrint(
          Provider.of<LocalizationService>(context, listen: false)
                  .translate('snowCleaningScheduleNotFound') ??
              'Raspored čišćenja snijega nije pronađen.',
        );
        return [];
      }

      final data = scheduleDoc.data();
      if (data == null || !data.containsKey('assignments')) {
        debugPrint(
          Provider.of<LocalizationService>(context, listen: false)
                  .translate('assignmentsFieldMissing') ??
              'Nema polja assignments u dokumentu.',
        );
        return [];
      }

      final assignments = data['assignments'] as Map<String, dynamic>;

      final now = DateTime.now();
      final List<Map<String, dynamic>> schedule = assignments.entries
          .map((entry) {
            final date = DateTime.parse(entry.key);
            final assignedUserId = entry.value as String;
            return {'date': date, 'userId': assignedUserId};
          })
          .where((entry) =>
              entry['userId'] == userId &&
              (entry['date'] as DateTime).isAfter(now))
          .toList();

      schedule.sort((a, b) => a['date'].compareTo(b['date']));
      return schedule;
    } catch (e) {
      debugPrint('Greška pri dohvaćanju rasporeda čišćenja snijega: $e');
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
        return Provider.of<LocalizationService>(context, listen: false)
                .translate('failedToFetchSaying') ??
            'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.';
      }
    } catch (e) {
      return Provider.of<LocalizationService>(context, listen: false)
              .translate('errorOccurred') ??
          'Došlo je do pogreške. Pokušajte kasnije.';
    }
  }

  List<Widget> _buildAnimatedCategoryCards(List<Widget> cards,
      {required bool exit}) {
    return List<Widget>.generate(cards.length, (index) {
      final beginOffset =
          (index % 2 == 0) ? const Offset(-1, 0) : const Offset(1, 0);
      final delay = index * 0.1;
      final slideAnimation = Tween<Offset>(
        begin: exit ? Offset.zero : beginOffset,
        end: exit ? beginOffset : Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _initialAnimationController,
          curve: Interval(
            delay.clamp(0.0, 1.0),
            (delay + 0.5).clamp(0.0, 1.0),
            curve: exit ? Curves.easeIn : Curves.easeOutBack,
          ),
        ),
      );
      final fadeAnimation = Tween<double>(
        begin: exit ? 1.0 : 0.8,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _initialAnimationController,
          curve: Interval(
            delay.clamp(0.0, 1.0),
            (delay + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeIn,
          ),
        ),
      );
      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: cards[index],
        ),
      );
    });
  }

  List<Widget> _buildDanceAnimatedCategoryCards(List<Widget> cards) {
    return List<Widget>.generate(cards.length, (index) {
      final tween = (index % 2 == 0)
          ? TweenSequence<Offset>([
              TweenSequenceItem(
                tween: Tween(begin: Offset.zero, end: const Offset(-0.1, 0))
                    .chain(CurveTween(curve: Curves.easeOut)),
                weight: 30,
              ),
              TweenSequenceItem(
                tween: Tween(begin: const Offset(-0.1, 0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.elasticOut)),
                weight: 150,
              ),
            ])
          : TweenSequence<Offset>([
              TweenSequenceItem(
                tween: Tween(begin: Offset.zero, end: const Offset(0.1, 0))
                    .chain(CurveTween(curve: Curves.easeOut)),
                weight: 30,
              ),
              TweenSequenceItem(
                tween: Tween(begin: const Offset(0.1, 0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.elasticOut)),
                weight: 150,
              ),
            ]);
      final slideAnimation = tween.animate(_danceAnimationController);
      return SlideTransition(
        position: slideAnimation,
        child: cards[index],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    final navigationService = GetIt.I<NavigationService>();

    final combinedCards =
        _buildCategoryCards(context, navigationService, localizationService);

    final animatedCards = _isDancing
        ? _buildDanceAnimatedCategoryCards(combinedCards)
        : _buildAnimatedCategoryCards(combinedCards, exit: _animateExit);

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                (displayName != null && displayName!.isNotEmpty)
                    ? displayName!
                    : (widget.username.isNotEmpty
                        ? widget.username
                        : localizationService.translate('unknownUser') ??
                            'Unknown User'),
              ),
              accountEmail: Text(
                FirebaseAuth.instance.currentUser?.email ??
                    (localizationService.translate('noEmail') ?? 'No Email'),
              ),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  (displayName != null && displayName!.isNotEmpty)
                      ? displayName![0].toUpperCase()
                      : (widget.username.isNotEmpty
                          ? widget.username[0].toUpperCase()
                          : (localizationService
                                  .translate('unknownUserInitial') ??
                              'U')),
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            // Ovdje možete dodati dodatne stavke ladice...
          ],
        ),
      ),
      body: Listener(
        onPointerMove: (event) {
          if (_scrollController.hasClients &&
              _scrollController.position.pixels <=
                  _scrollController.position.minScrollExtent &&
              event.delta.dy > 0) {
            _dragDistance += event.delta.dy;
            if (_dragDistance > 50) {
              _triggerDanceAnimation();
              _dragDistance = 0;
            }
          }
        },
        onPointerUp: (_) {
          _dragDistance = 0;
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.count(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            children: animatedCards,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryCards(
    BuildContext context,
    NavigationService navigationService,
    LocalizationService localizationService,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    List<Widget> baseCards = [];

    // Službene obavijesti.
    if (_enabledModules['officialNotices'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('officialNotices'),
          title: localizationService.translate('officialNotices') ??
              'Official Notices',
          subtitleStream: _firebaseService.getLatestContentTitleStream(
            widget.countryId,
            widget.cityId,
            widget.locationId,
            'blogs',
          ),
          newItemsCountStream: _firebaseService.getNewBlogsCount(
            widget.countryId,
            widget.cityId,
            widget.locationId,
          ),
          color: const Color(0xFF3F51B5),
          icon: Icons.campaign,
          onTap: () => Navigator.pushNamed(
            context,
            '/blog',
            arguments: {
              'username': widget.username,
              'countryId': widget.countryId,
              'cityId': widget.cityId,
              'locationId': widget.locationId,
            },
          ),
        ),
      );
    }

    // Marketplace.
    baseCards.add(
      _buildCategoryCard(
        context,
        key: ValueKey('marketplace'),
        title: localizationService.translate('marketplace') ?? 'Marketplace',
        subtitleFuture: _randomAdTitlesFuture.then((titles) {
          if (titles.isEmpty) {
            return localizationService.translate('noAdsAvailable') ??
                'No ads available';
          }
          return titles.join('\n');
        }),
        newItemsCountStream: _firebaseService.getNewPostsCountStream(
          widget.countryId,
          widget.cityId,
          widget.locationId,
          'marketplace',
        ),
        color: const Color(0xFFFF5722),
        icon: Icons.store,
        onTap: () => navigationService.navigateToCategory(
          context,
          route: '/marketplace',
          categoryField: 'marketplace',
          username: widget.username,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );

    // Chat soba.
    if (_enabledModules['chatRoom'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('chatRoom'),
          title: localizationService.translate('chatRoom') ?? 'Chat Room',
          subtitleStream: _firebaseService.getLatestContentTitleStream(
            widget.countryId,
            widget.cityId,
            widget.locationId,
            'chats',
          ),
          newItemsCountStream: _firebaseService.getNewPostsCountStream(
            widget.countryId,
            widget.cityId,
            widget.locationId,
            'chats',
          ),
          color: const Color(0xFF4CAF50),
          icon: Icons.chat,
          onTap: () => navigationService.navigateToCategory(
            context,
            route: '/chat',
            categoryField: 'chats',
            username: widget.username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
          ),
        ),
      );
    }

    // Report Issue Card (Home Repair).
    baseCards.add(
      StreamBuilder<RepairRequest?>(
        stream: _firebaseService.getLatestActiveRepairRequest(userId),
        builder: (context, snapshot) {
          String? statusMessage;
          IconData? statusIcon;
          Color? statusColor;
          bool hasNewNotification = false;

          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData && snapshot.data != null) {
              final repairData = snapshot.data!.toMap();
              hasNewNotification = !snapshot.data!.notificationSeen;
              final statusDetails =
                  getRepairStatusDetails(repairData, localizationService);
              statusMessage = statusDetails['message'];
              statusIcon = statusDetails['icon'];
              statusColor = statusDetails['color'];
            } else {
              statusMessage =
                  localizationService.translate('noActiveRequests') ??
                      'Nema aktivnih zahtjeva';
              hasNewNotification = false;
              statusIcon = Icons.info_outline;
              statusColor = Colors.grey;
            }
          }

          return _buildCategoryCard(
            context,
            key: ValueKey('reportIssue'),
            title: localizationService.translate('reportIssue') ??
                'Prijavi Problem',
            color: const Color(0xFFF44336),
            icon: Icons.build,
            subtitleFuture: _fetchRepairRequestStatus().then((repairData) {
              if (repairData.containsKey('status')) {
                final status = repairData['status'];
                switch (status) {
                  case 'Published':
                    return localizationService
                            .translate('searchingForServicer') ??
                        'Tražimo servisera!';
                  case 'In Negotiation':
                    return localizationService.translate('inNegotiation') ??
                        'Pregovori u tijeku.';
                  case 'Job Agreed':
                    return localizationService.translate('serviceConfirmed') ??
                        'Servis dogovoren!';
                  case 'waitingforconfirmation':
                    return localizationService
                            .translate('waitingforconfirmation') ??
                        'Čekamo potvrdu termina.';
                  case 'Published_2':
                    return localizationService
                            .translate('chooseServicerArrivalTime') ??
                        'Odaberite termin dolaska servisera.';
                  default:
                    return localizationService.translate('unknownStatus') ??
                        'Nepoznat status';
                }
              } else {
                return localizationService.translate('noActiveRequests') ??
                    'Nema aktivnih zahtjeva';
              }
            }),
            hasNewNotification: hasNewNotification,
            statusIcon: statusIcon,
            statusColor: statusColor,
            onTap: () {
              navigationService.navigateToCategory(
                context,
                route: '/report',
                categoryField: 'homeRepairService',
                username: widget.username,
                countryId: widget.countryId,
                cityId: widget.cityId,
                locationId: widget.locationId,
              );
            },
          );
        },
      ),
    );

    // Kviz.
    if (_enabledModules['quiz'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('quiz'),
          title: localizationService.translate('quiz') ?? 'Kviz',
          color: const Color(0xFF2196F3),
          icon: Icons.games,
          onTap: () => navigationService.navigateToCategory(
            context,
            route: '/games',
            categoryField: 'games',
            username: widget.username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
          ),
          subtitleFuture: _fetchPlayersWhoPlayedToday().then((players) {
            if (players.isEmpty) {
              return localizationService.translate('no_players_played_today') ??
                  'Nema igrača danas.';
            }
            return players.join(', ');
          }),
        ),
      );
    }

    // Bulletin Board.
    if (_enabledModules['bulletinBoard'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('bulletinBoard'),
          title: localizationService.translate('bulletinBoard') ??
              'Bulletin Board',
          subtitleStream: _firebaseService.getLatestContentTitleStream(
            widget.countryId,
            widget.cityId,
            widget.locationId,
            'bulletin_board',
          ),
          newItemsCountStream: _firebaseService.getNewPostsCountStream(
            widget.countryId,
            widget.cityId,
            widget.locationId,
            'bulletin_board',
          ),
          color: const Color(0xFFFFC107),
          icon: Icons.announcement,
          onTap: () => navigationService.navigateToCategory(
            context,
            route: '/bulletin',
            categoryField: 'bulletin_board',
            username: widget.username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
          ),
        ),
      );
    }

    // Documents.
    baseCards.add(
      _buildCategoryCard(
        context,
        key: ValueKey('documents'),
        title: localizationService.translate('documents') ?? 'Documents',
        subtitleStream: _firebaseService.getLatestContentTitleStream(
          widget.countryId,
          widget.cityId,
          widget.locationId,
          'documents',
        ),
        newItemsCountStream: _firebaseService.getNewDocumentsCountStream(
          widget.countryId,
          widget.cityId,
          widget.locationId,
        ),
        color: const Color(0xFFFF9800),
        icon: Icons.description,
        onTap: () => navigationService.navigateToCategory(
          context,
          route: '/documents',
          categoryField: 'documents',
          username: widget.username,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );

    // Parking zajednica.
    if (_enabledModules['parkingCommunity'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('parkingCommunity'),
          title: localizationService.translate('parkingCommunity') ??
              'Parking Zajednica',
          color: Colors.green,
          icon: Icons.local_parking,
          onTap: () => navigationService.navigateToCategory(
            context,
            route: '/parking_community',
            categoryField: 'parking_community',
            username: widget.username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
          ),
        ),
      );
    }

    // Shared Transport.
    baseCards.add(
      _buildCategoryCard(
        context,
        key: ValueKey('sharedTransport'),
        title: localizationService.translate('sharedTransport') ??
            'Shared Transport',
        color: const Color(0xFF8BC34A),
        icon: Icons.directions_car,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommuteRidesListScreen(
              username: widget.username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        ),
      ),
    );

    // Mudra sova.
    if (_enabledModules['wiseOwl'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('wiseOwl'),
          title: localizationService.translate('wiseOwl') ?? 'Wise Owl',
          color: const Color(0xFF673AB7),
          icon: Icons.school,
          subtitleFuture: _wiseOwlSubtitleFuture.then((saying) {
            if (saying ==
                (localizationService.translate('failedToFetchSaying') ??
                    'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.')) {
              return localizationService.translate('failedToFetchSaying') ??
                  'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.';
            } else if (saying ==
                (localizationService.translate('errorOccurred') ??
                    'Došlo je do pogreške. Pokušajte kasnije.')) {
              return localizationService.translate('errorOccurred') ??
                  'Došlo je do pogreške. Pokušajte kasnije.';
            } else {
              return saying;
            }
          }),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WiseOwlScreen(),
            ),
          ),
        ),
      );
    }

    // Čišćenje snijega.
    if ((_enabledModules['snowCleaning'] ?? true) &&
        widget.locationId.isNotEmpty) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('snowCleaning'),
          title: localizationService.translate('snowCleaning') ??
              'Čišćenje snijega',
          color: const Color(0xFF607D8B),
          icon: Icons.snowing,
          subtitleFuture: _fetchSnowCleaningSchedule().then((schedule) {
            if (schedule.isEmpty) {
              return localizationService.translate('noSnowCleaningTasks') ??
                  'Nema zadataka čišćenja.';
            }
            // Uzimamo najviše 3 nadolazeća datuma.
            return schedule.take(3).map((task) {
              final date = task['date'] as DateTime;
              return '${date.day.toString().padLeft(2, '0')}.'
                  '${date.month.toString().padLeft(2, '0')}.'
                  '${date.year}';
            }).join('\n');
          }),
          subtitleMaxLines: 2,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SnowCleaningScreen(
                countryId: widget.countryId,
                cityId: widget.cityId,
                locationId: widget.locationId,
                username: widget.username,
              ),
            ),
          ),
        ),
      );
    }

    // Sigurnost.
    if (_enabledModules['security'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('security'),
          title: localizationService.translate('security') ?? 'Security',
          color: Colors.blue,
          icon: Icons.security,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/security',
              arguments: {
                'username': widget.username,
                'countryId': widget.countryId,
                'cityId': widget.cityId,
                'locationId': widget.locationId,
                'locationAdmin': widget.locationAdmin,
              },
            );
          },
        ),
      );
    }

    // Alarm.
    if (_enabledModules['alarm'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('alarm'),
          title: localizationService.translate('alarm') ?? 'Alarm',
          color: Colors.redAccent,
          icon: Icons.fireplace,
          onTap: () async {
            final bool? confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    localizationService.translate('confirmation') ??
                        'Confirmation',
                  ),
                  content: Text(
                    localizationService.translate('areYouSure') ??
                        'Are you sure you want to do this?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: Text(
                        localizationService.translate('cancel') ?? 'Cancel',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      child: Text(
                        localizationService.translate('confirm') ?? 'Confirm',
                      ),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              navigationService.navigateToCategory(
                context,
                route: '/alarm',
                categoryField: 'alarm',
                username: widget.username,
                countryId: widget.countryId,
                cityId: widget.cityId,
                locationId: widget.locationId,
              );
            }
          },
        ),
      );
    }

    // Noise (Buka).
    if (_enabledModules['noise'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('noise'),
          title: localizationService.translate('noise') ?? 'Noise',
          color: const Color(0xFFFF7043),
          icon: Icons.construction,
          subtitleFuture: _fetchNearestWorks(),
          onTap: () => navigationService.navigateToCategory(
            context,
            route: '/construction',
            categoryField: 'noisy',
            username: widget.username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
          ),
        ),
      );
    }

    // Comments & Suggestions.
    baseCards.add(
      _buildCategoryCard(
        context,
        key: ValueKey('commentsSuggestions'),
        title: localizationService.translate('commentsSuggestions') ??
            'Comments & Suggestions',
        color: const Color(0xFF795548),
        icon: Icons.feedback,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VoxPopuliScreen(),
          ),
        ),
      ),
    );

    // Settings.
    baseCards.add(
      _buildCategoryCard(
        context,
        key: ValueKey('settings'),
        title: localizationService.translate('settings') ?? 'Settings',
        color: const Color(0xFF9E9E9E),
        icon: Icons.settings,
        onTap: () => navigationService.navigateToCategory(
          context,
          route: '/settings',
          categoryField: 'settings',
          username: widget.username,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );

    // Ako je admin - dodaj "directContact"
    if (widget.locationAdmin) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: const ValueKey('directContact'),
          title: localizationService.translate('directContact') ??
              'Direct Contact',
          color: const Color(0xFF424242),
          icon: Icons.feedback,
          onTap: () {
            String locName = locationName ??
                (localizationService.translate('unknownLocation') ??
                    'Nepoznata lokacija');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminVoxPopuliScreen(
                  locationId: widget.locationId,
                  locationName: locName,
                ),
              ),
            );
          },
        ),
      );
    }

    // Očitanja.
    if (_enabledModules['readings'] ?? true) {
      baseCards.add(
        _buildCategoryCard(
          context,
          key: ValueKey('readings'),
          title: localizationService.translate('readings') ?? 'Očitanja',
          color: const Color(0xFF4DB6AC),
          icon: Icons.electrical_services,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadingsScreen(
                locationId: widget.locationId,
              ),
            ),
          ),
        ),
      );
    }

    // Oglasne kartice.
    List<Widget> adCards = [];
    if (randomAds.isNotEmpty) {
      for (var ad in randomAds) {
        adCards.add(_buildAdCard(ad));
      }
    }

    // Kombinirano.
    return List<Widget>.from(baseCards)..addAll(adCards);
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required Key key,
    required String title,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    Stream<String>? subtitleStream,
    Future<String>? subtitleFuture,
    Stream<int>? newItemsCountStream,
    String? subtitle,
    IconData? statusIcon,
    Color? statusColor,
    bool hasNewNotification = false,
    int subtitleMaxLines = 3,
  }) {
    return AnimatedCategoryCard(
      key: key,
      title: title,
      color: color,
      icon: icon,
      onTap: onTap,
      subtitleStream: subtitleStream,
      subtitleFuture: subtitleFuture,
      newItemsCountStream: newItemsCountStream,
      subtitle: subtitle,
      statusIcon: statusIcon,
      statusColor: statusColor,
      hasNewNotification: hasNewNotification,
      subtitleMaxLines: subtitleMaxLines,
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    return GestureDetector(
      key: ValueKey(ad['title'] ?? UniqueKey()),
      onTap: () => _showAdDetails(ad),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              spreadRadius: 2,
              blurRadius: 3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ad['imageUrl'] != null && ad['imageUrl'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ad['imageUrl'],
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/marketplace_1.jpg',
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 8.0,
                ),
                child: Text(
                  ad['title'] ??
                      (localizationService.translate('noTitle') ?? 'No Title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> getNewDailySayingStream() async {
    return await getNewDailySayingFuture();
  }

  void _showAdDetails(Map<String, dynamic> ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdDetailScreen(
          ad: ad,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );
  }
}
