// lib/services/service_locator.dart

import 'package:get_it/get_it.dart';
import 'fcm_service.dart';
import 'user_service.dart';

final GetIt getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<UserService>(() => UserService());
  getIt.registerLazySingleton<FCMService>(() => FCMService());
  // Dodajte ostale servise ovdje
}
