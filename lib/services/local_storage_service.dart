import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _lastScreenKey = 'lastScreen';
  static const String _lastLevelKey = 'lastLevel';

  // Spremanje zadnje aktivnosti
  Future<void> saveUserLastActivity({
    required String screenName,
    String? level,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScreenKey, screenName);
    if (level != null) await prefs.setString(_lastLevelKey, level);
  }

  // Dohvaćanje zadnje aktivnosti
  Future<Map<String, String?>> loadUserLastActivity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'screen': prefs.getString(_lastScreenKey),
      'level': prefs.getString(_lastLevelKey),
    };
  }
}
