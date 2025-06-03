import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService with ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  int _notificationCounter = 0; // Privatni brojač za obavijesti

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Rukovanje navigacijom ako payload postoji
        if (response.payload != null) {
          // Implementacija navigacije na specifičan ekran
        }
      },
    );
  }

  // Metoda za prikaz lokalne notifikacije
  Future<void> showNotification(RemoteMessage message) async {
    _notificationCounter++; // Inkrementira brojač obavijesti
    notifyListeners(); // Obavještava UI o promjeni brojača

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel_id',
      'Chat Notifications',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: message.data['chatId'],
    );
  }

  // Getter za dohvat trenutnog brojača obavijesti
  int get notificationCounter => _notificationCounter;

  // Getter za dohvat broja novih obavijesti
  int get newNotificationsCount => _notificationCounter;

  // Metoda za resetiranje brojača obavijesti
  void resetNotificationCounter() {
    _notificationCounter = 0;
    notifyListeners(); // Obavještava UI o promjeni brojača
  }

  // Dodana metoda resetiranja
  void reset() {
    _notificationCounter = 0;
    notifyListeners();
  }

  // Metoda za inkrementaciju brojača obavijesti bez prikazivanja obavijesti
  void increment() {
    _notificationCounter++;
    notifyListeners(); // Obavještava UI o promjeni brojača
  }
}
