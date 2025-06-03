import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import '../main.dart'; // Uvoz globalnog navigatorKey-a

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  _LanguageSelectionScreenState createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'en';
  final Map<String, String> languages = {
    'en': '🇬🇧 English',
    'ar': '🇸🇦 العربية',
    'bn': '🇧🇩 বাংলা',
    'bs': '🇧🇦 Bosanski',
    'da': '🇩🇰 Dansk',
    'de': '🇩🇪 Deutsch',
    'es': '🇪🇸 Español',
    'fa': '🇮🇷 فارسی',
    'fi': '🇫🇮 Suomi',
    'fr': '🇫🇷 Français',
    'hi': '🇮🇳 हिन्दी',
    'hr': '🇭🇷 Hrvatski',
    'hu': '🇭🇺 Magyar',
    'id': '🇮🇩 Bahasa Indonesia',
    'is': '🇮🇸 Íslenska',
    'it': '🇮🇹 Italiano',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'nl': '🇳🇱 Nederlands',
    'no': '🇳🇴 Norsk',
    'pl': '🇵🇱 Polski',
    'pt': '🇵🇹 Português',
    'ro': '🇷🇴 Română',
    'ru': '🇷🇺 Русский',
    'sl': '🇸🇮 Slovensko',
    'sr': '🇷🇸 Srpski',
    'sv': '🇸🇪 Svenska',
    'th': '🇹🇭 ไทย',
    'tr': '🇹🇷 Türkçe',
    'vi': '🇻🇳 Tiếng Việt',
  };

  void _selectLanguage(String languageCode) async {
    final localizationService = LocalizationService.instance;
    await localizationService.loadLanguage(languageCode);
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    if (!onboardingCompleted) {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnboardingScreen(
            onFinish: () {
              prefs.setBool('onboarding_completed', true);
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            onSkip: () {
              prefs.setBool('onboarding_completed', true);
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ),
      );
    } else {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                style: const TextStyle(fontSize: 20, color: Colors.black),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                  }
                },
                items: languages.entries.map<DropdownMenuItem<String>>((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child:
                        Text(entry.value, style: const TextStyle(fontSize: 20)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _selectLanguage(_selectedLanguage);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                icon: const Icon(Icons.arrow_forward,
                    color: Colors.white, size: 24),
                label: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
