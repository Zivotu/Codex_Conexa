import 'package:flutter/foundation.dart'; // Za kReleaseMode
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Za notifikacije
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Za Firebase inicijalizaciju
import '../main.dart' as main; // Alias za main.dart
import '../shared_state.dart'; // Za SharedState

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      if (notificationResponse.payload != null) {
        debugPrint('Notification payload: ${notificationResponse.payload}');
        if (kReleaseMode) {
          debugPrint(
              'Notification payload (Release): ${notificationResponse.payload}');
        }
        main.navigatorKey.currentState?.pushNamed(
          '/chat',
          arguments: {
            'username': FirebaseAuth.instance.currentUser?.displayName,
            'locationId': notificationResponse.payload,
          },
        );
      }
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel',
    'Default Notifications',
    description: 'All default notifications',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> showNotification(RemoteMessage message) async {
  if (SharedState.isUserInChat) {
    if (kReleaseMode) {
      debugPrint('Notification suppressed in showNotification function.');
    }
    return;
  }

  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
    'default_channel',
    'Default Notifications',
    channelDescription: 'All default notifications',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  await flutterLocalNotificationsPlugin.show(
    message.messageId.hashCode,
    message.notification?.title,
    message.notification?.body,
    notificationDetails,
    payload: message.data['locationId'],
  );

  debugPrint('Notification shown with messageId: ${message.messageId}');
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Ispravan poziv Firebase.initializeApp
  showNotification(message);
}
