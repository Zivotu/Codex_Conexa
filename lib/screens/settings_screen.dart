import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'settings_alarm_setup_screen.dart';
import 'settings_edit_profile_screen.dart';
import 'create_location_screen.dart';
import 'login_screen.dart';
import '../services/user_service.dart' as user_service;
import '../services/location_service.dart' as location_service;
import '../services/city_service.dart' as city_service;
import '../services/localization_service.dart';
import 'payment_dashboard_screen.dart'; // novi ekran dashboarda

class SettingsScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final bool locationAdmin;
  final user_service.UserService userService = user_service.UserService();
  final location_service.LocationService locationService =
      location_service.LocationService();
  final city_service.CityService cityService = city_service.CityService();

  SettingsScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationAdmin,
  });

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'hr';

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String currentLanguage = localizationService.currentLanguage;
    setState(() {
      _selectedLanguage = currentLanguage;
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    await localizationService.loadLanguage(languageCode);
  }

  /// Pomoćna metoda za kreiranje kartica sa standardnim opcijama
  Widget _buildOptionCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  /// Pomoćna metoda za kreiranje kartica s prilagođenom pozadinskom bojom i bijelim tekstom
  Widget _buildColoredOptionCard({
    required Color color,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color,
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('settings') ?? 'Settings'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Jezični odabir – ostaje bez kartice
            DropdownButton<String>(
              value: _selectedLanguage,
              onChanged: (String? newLanguage) {
                if (newLanguage != null) {
                  setState(() {
                    _selectedLanguage = newLanguage;
                  });
                  _changeLanguage(newLanguage);
                }
              },
              items: const [
                DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                DropdownMenuItem(value: 'ar', child: Text('🇸🇦 العربية')),
                DropdownMenuItem(value: 'bn', child: Text('🇧🇩 বাংলা')),
                DropdownMenuItem(value: 'bs', child: Text('🇧🇦 Bosanski')),
                DropdownMenuItem(value: 'da', child: Text('🇩🇰 Dansk')),
                DropdownMenuItem(value: 'de', child: Text('🇩🇪 Deutsch')),
                DropdownMenuItem(value: 'es', child: Text('🇪🇸 Español')),
                DropdownMenuItem(value: 'fa', child: Text('🇮🇷 فارسی')),
                DropdownMenuItem(value: 'fi', child: Text('🇫🇮 Suomi')),
                DropdownMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
                DropdownMenuItem(value: 'hi', child: Text('🇮🇳 हिन्दी')),
                DropdownMenuItem(value: 'hr', child: Text('🇭🇷 Hrvatski')),
                DropdownMenuItem(value: 'hu', child: Text('🇭🇺 Magyar')),
                DropdownMenuItem(
                    value: 'id', child: Text('🇮🇩 Bahasa Indonesia')),
                DropdownMenuItem(value: 'is', child: Text('🇮🇸 Íslenska')),
                DropdownMenuItem(value: 'it', child: Text('🇮🇹 Italiano')),
                DropdownMenuItem(value: 'ja', child: Text('🇯🇵 日本語')),
                DropdownMenuItem(value: 'ko', child: Text('🇰🇷 한국어')),
                DropdownMenuItem(value: 'nl', child: Text('🇳🇱 Nederlands')),
                DropdownMenuItem(value: 'no', child: Text('🇳🇴 Norsk')),
                DropdownMenuItem(value: 'pl', child: Text('🇵🇱 Polski')),
                DropdownMenuItem(value: 'pt', child: Text('🇵🇹 Português')),
                DropdownMenuItem(value: 'ro', child: Text('🇷🇴 Română')),
                DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Русский')),
                DropdownMenuItem(value: 'sl', child: Text('🇸🇮 Slovensko')),
                DropdownMenuItem(value: 'sr', child: Text('🇷🇸 Srpski')),
                DropdownMenuItem(value: 'sv', child: Text('🇸🇪 Svenska')),
                DropdownMenuItem(value: 'th', child: Text('🇹🇭 ไทย')),
                DropdownMenuItem(value: 'tr', child: Text('🇹🇷 Türkçe')),
                DropdownMenuItem(value: 'vi', child: Text('🇻🇳 Tiếng Việt')),
              ],
              hint: Text(localizationService.translate('select_language') ??
                  'Odaberite jezik'),
            ),
            const SizedBox(height: 8),
            // Alarm Setup
            _buildOptionCard(
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(
                  localizationService.translate('alarm_setup') ?? 'Alarm Setup',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsAlarmSetupScreen(
                        countryId: widget.countryId,
                        cityId: widget.cityId,
                        locationId: widget.locationId,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Edit Profile
            _buildOptionCard(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  localizationService.translate('edit_profile') ??
                      'Edit Profile',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsEditProfileScreen(
                        countryId: widget.countryId,
                        cityId: widget.cityId,
                        locationId: widget.locationId,
                        userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
              ),
            ),
            // Kreiraj novu lokaciju – plava pozadina s bijelim tekstom
            _buildColoredOptionCard(
              color: const Color(0xFF2196F3),
              icon: Icons.add_location,
              title: localizationService.translate('create_location') ??
                  'Kreiraj novu lokaciju',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateLocationScreen(
                      username: widget.username,
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                      locationId: widget.locationId,
                    ),
                  ),
                );
              },
            ),
            // Sustav naplate – zelena pozadina s bijelim tekstom
            _buildColoredOptionCard(
              color: const Color(0xFF4CAF50),
              icon: Icons.payment,
              title: 'Sustav naplate',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentDashboardScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            // Log Out
            _buildOptionCard(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text(
                  localizationService.translate('logout') ?? 'Log Out',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
