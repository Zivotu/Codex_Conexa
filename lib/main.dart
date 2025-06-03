import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/user_locations_screen.dart';
import 'screens/join_location_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_service.dart';
import 'services/navigation_service.dart';
import 'services/localization_service.dart';
import 'services/fcm_service.dart';
import 'services/servicer_service.dart';
import 'services/subscription_service.dart';
import 'services/commute_service.dart';
import 'text_styles.dart';
import 'providers/time_slot_provider.dart';
import 'viewmodels/ride_view_model.dart';

// Globalni ključ za navigaciju
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Inicijalizacija Logger‑a
final Logger _logger = Logger();

// Inicijalizacija lokalnih notifikacija
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeLocalNotifications() async {
  try {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
      macOS: null,
    );
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Default Notifications',
      description: 'Notifications for general purposes',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _navigateToChatScreen(payload);
      },
    );
    _logger.d('Lokalne notifikacije inicijalizirane.');
  } catch (e) {
    _logger.e('Greška pri inicijalizaciji lokalnih notifikacija: $e');
  }
}

void _navigateToChatScreen(String chatId) {
  try {
    navigatorKey.currentState
        ?.pushNamed('/chat', arguments: {'chatId': chatId});
    _logger.d("Navigating to chat screen with chatId: $chatId");
  } catch (e) {
    _logger.e("Greška pri navigaciji na chat ekran: $e");
  }
}

void setupServiceLocator() {
  GetIt.I.registerSingleton<NavigationService>(NavigationService());
  GetIt.I.registerSingleton<UserService>(UserService());
  GetIt.I.registerSingleton<ServicerService>(ServicerService());
  GetIt.I.registerSingleton<FCMService>(FCMService());
  GetIt.I.registerSingleton<CommuteService>(CommuteService());
}

Future<void> requestStoragePermissions() async {
  if (Platform.isAndroid) {
    var info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted && status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } else {
      var status = await Permission.storage.request();
      if (!status.isGranted && status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }
}

Future<void> cleanOldCacheFiles({int daysThreshold = 1}) async {
  try {
    final cacheDir = await getTemporaryDirectory();
    final now = DateTime.now();
    for (var file in cacheDir.listSync()) {
      if (file is File) {
        final diff = now.difference(await file.lastModified()).inDays;
        if (diff > daysThreshold) await file.delete();
      }
    }
    _logger.d('Stari cache datoteke očišćene.');
  } catch (e) {
    _logger.e('Greška pri čišćenju cache datoteka: $e');
  }
}

Future<bool> checkForUpdate(BuildContext context) async {
  try {
    _logger.i('Provjeravanje za ažuriranje...');
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 300),
      minimumFetchInterval: Duration.zero,
    ));
    await rc.fetchAndActivate();
    final pkg = await PackageInfo.fromPlatform();
    final current = int.parse(pkg.buildNumber);
    final remote = int.tryParse(rc.getString('latest_version_code')) ?? current;
    final url = rc.getString('latest_version_url');
    if (remote > current) {
      bool? choice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Ažuriranje dostupno'),
          content: const Text(
              'Nova verzija aplikacije je dostupna. Želite li je preuzeti?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ne')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  _openPlayStore();
                },
                child: const Text('Ažuriraj')),
          ],
        ),
      );
      return choice ?? false;
    }
    return false;
  } catch (e) {
    _logger.e('Greška pri provjeri ažuriranja: $e');
    return false;
  }
}

void _openPlayStore() async {
  const url =
      'https://play.google.com/store/apps/details?id=dreamteamstudio.online.conexa';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    _logger.e("Ne mogu otvoriti URL: $url");
  }
}

Future<void> requestNotificationPermissions() async {
  try {
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    _logger.i('Dozvole za notifikacije zatražene.');
  } catch (e) {
    _logger.e('Greška pri zahtjevu za dozvole notifikacija: $e');
  }
}

Future<void> subscribeToTopic(String topic) async {
  try {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    _logger.d("Subscribed to topic: $topic");
  } catch (e) {
    _logger.e("Failed to subscribe to topic: $topic, Error: $e");
  }
}

Future<bool> isInstallPermissionGranted() async {
  if (Platform.isAndroid) {
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
    }
    return status.isGranted;
  }
  return true;
}

Future<void> _initDynamicLinks() async {
  try {
    final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    final deepLink = initialLink?.link;
    if (deepLink != null) _handleIncomingLink(deepLink);
    FirebaseDynamicLinks.instance.onLink.listen((data) {
      _handleIncomingLink(data.link);
    }).onError((e) {
      _logger.e("Greška pri dynamic linku: $e");
    });
  } catch (e) {
    _logger.e("Greška pri inicijalizaciji Dynamic Links: $e");
  }
}

void _handleIncomingLink(Uri uri) {
  final countryId = uri.queryParameters['countryId'];
  final cityId = uri.queryParameters['cityId'];
  final locationId = uri.queryParameters['locationId'];
  if (countryId != null && cityId != null && locationId != null) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => JoinLocationScreen(
        countryId: countryId,
        cityId: cityId,
        locationId: locationId,
      ),
    ));
  } else {
    _logger.e("Dynamic link nema potrebne parametre.");
  }
}

Future<void> _registerAppLaunch() async {
  try {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ref = FirebaseFirestore.instance.collection('appOpens').doc(today);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {'count': FieldValue.increment(1)});
      } else {
        tx.set(ref, {'count': 1});
      }
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uniqRef =
          FirebaseFirestore.instance.collection('appOpens_unique').doc(today);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(uniqRef);
        final list =
            snap.exists ? (snap.data()?['userIds'] as List) : <String>[];
        if (!list.contains(user.uid)) {
          list.add(user.uid);
          if (snap.exists) {
            tx.update(uniqRef, {'userIds': list});
          } else {
            tx.set(uniqRef, {'userIds': list});
          }
        }
      });
    }
  } catch (e) {
    _logger.e("Greška pri registraciji otvaranja aplikacije: $e");
  }
}

Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
}

Future<void> setOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', true);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logger.d('Initializing Firebase');
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _logger.d('Firebase initialized.');
  } catch (e) {
    _logger.e('Firebase initialization failed: $e');
  }

  await Purchases.setDebugLogsEnabled(true);
  await Purchases.configure(
      PurchasesConfiguration("goog_aIQgWOvJPtXYYkjnlXtcjFbZzwI"));

  await cleanOldCacheFiles();
  await requestNotificationPermissions();
  await requestStoragePermissions();
  setupServiceLocator();

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
    _logger.d('Firebase App Check activated.');
  } catch (e) {
    _logger.e('Firebase App Check activation failed: $e');
  }

  await _initializeLocalNotifications();

  final localizationService = LocalizationService();
  try {
    await localizationService.init();
    _logger.d('LocalizationService initialized.');
  } catch (e) {
    _logger.e('LocalizationService initialization failed: $e');
  }

  await _initDynamicLinks();
  await GetIt.I<FCMService>().init();
  await _registerAppLaunch();

  // Odabir početnog ekrana
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? selectedLanguage = prefs.getString('selectedLanguage');
  Widget initialScreen;
  if (selectedLanguage == null || selectedLanguage.isEmpty) {
    initialScreen = const LanguageSelectionScreen();
  } else {
    bool onboarded = prefs.getBool('onboarding_completed') ?? false;
    if (!onboarded) {
      initialScreen = OnboardingScreen(
        onFinish: () {
          prefs.setBool('onboarding_completed', true);
          navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
        onSkip: () {
          prefs.setBool('onboarding_completed', true);
          navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        },
      );
    } else {
      final user = FirebaseAuth.instance.currentUser;
      initialScreen = user != null ? const AuthHandler() : const LoginScreen();
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => localizationService),
        ChangeNotifierProvider(create: (_) => TimeSlotProvider()),
        Provider<ServicerService>(create: (_) => ServicerService()),
        Provider<CommuteService>(create: (_) => CommuteService()),
        Provider<UserService>.value(value: GetIt.I<UserService>()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        ChangeNotifierProvider<RideViewModel>(
          create: (context) => RideViewModel(
            commuteService: context.read<CommuteService>(),
            userService: context.read<UserService>(),
          ),
        ),
      ],
      child: MyApp(initialScreen: initialScreen),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({required this.initialScreen, super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    return MaterialApp(
      title: 'Conexa',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'RobotoMono',
        textTheme: const TextTheme(
          headlineSmall: TextStyles.headlineSmall,
          bodySmall: TextStyles.bodySmall,
          bodyLarge: TextStyles.bodyLarge,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('hr', ''),
        Locale('de', ''),
      ],
      locale: localizationService.currentLanguage.isNotEmpty
          ? Locale(localizationService.currentLanguage, '')
          : null,
      navigatorKey: navigatorKey,
      onGenerateRoute: generateRoute,
      home: initialScreen,
    );
  }
}

class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});
  @override
  AuthHandlerState createState() => AuthHandlerState();
}

class AuthHandlerState extends State<AuthHandler> {
  bool _handledUserLogin = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) {
          final user = snap.data!;
          return FutureBuilder<Map<String, dynamic>?>(
            future: GetIt.I<UserService>().getUserDocumentById(user.uid),
            builder: (ctx, us) {
              if (us.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (us.hasData) {
                if (!_handledUserLogin) {
                  _handledUserLogin = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    GetIt.I<FCMService>().handleUserLogin(user);
                  });
                }
                final data = us.data!;
                return UserLocationsScreen(
                    username: data['username'] ?? 'Korisnik');
              }
              return const LoginScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final String username;
  final String displayName;
  final bool locationAdmin;
  final bool isFunnyMode;
  final String? countryId;
  final String? cityId;
  final String? locationId;
  final bool isAnonymous;

  const MainScreen({
    super.key,
    required this.username,
    required this.displayName,
    required this.locationAdmin,
    required this.isFunnyMode,
    this.countryId,
    this.cityId,
    this.locationId,
    required this.isAnonymous,
  });

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int unreadPostsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.countryId == null ||
          widget.cityId == null ||
          widget.locationId == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => const UserLocationsScreen(username: 'Korisnik')),
        );
      } else {
        _getUnreadPosts();
        if (widget.cityId != null) {
          subscribeToTopic('city_${widget.cityId}');
        }
        _setupFCMListeners();
      }
    });
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((msg) {
      if (msg.notification != null) _showLocalNotification(msg);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data.containsKey('chatId')) {
        _navigateToChatScreen(msg.data['chatId']);
      }
    });
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
        'default_channel', 'Default Notifications',
        importance: Importance.max, priority: Priority.high, playSound: true);
    const platformDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: message.data['chatId'],
    );
  }

  void _getUnreadPosts() {
    FirebaseFirestore.instance
        .collection('local_community')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('posts')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      setState(() => unreadPostsCount = snap.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen - $unreadPostsCount nepročitanih postova'),
      ),
      body: Center(
        child: Text(
          'Dobrodošli, ${widget.username}!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger().d("Handling a background message: ${message.messageId}");
}
