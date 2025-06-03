import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LocalizationService with ChangeNotifier {
  // Singleton instance
  static final LocalizationService instance = LocalizationService._internal();

  factory LocalizationService() {
    return instance;
  }

  LocalizationService._internal();

  Map<String, String>? _localizedStrings;
  String _currentLanguage = ''; // Nema default jezika – prazan string

  // Učitavanje jezika iz JSON datoteke
  Future<void> loadLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    try {
      final String jsonString =
          await rootBundle.loadString('assets/lang/$languageCode.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings =
          jsonMap.map((key, value) => MapEntry(key, value.toString()));

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', languageCode);

      notifyListeners(); // Osvježavanje listenera
    } catch (e) {
      // U slučaju greške, možete logirati ili postaviti fallback jezik
      _localizedStrings = {};
      notifyListeners();
    }
  }

  // Prevođenje ključa na trenutni jezik
  String translate(String key) {
    return _localizedStrings?[key] ?? key;
  }

  // Dohvaćanje trenutnog jezika
  String get currentLanguage => _currentLanguage;

  // Inicijalizacija servisa za lokalizaciju
  Future<void> init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('selectedLanguage');
    if (languageCode != null && languageCode.isNotEmpty) {
      await loadLanguage(languageCode);
    }
  }
}
