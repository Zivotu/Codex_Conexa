import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import 'infos/info_alarm.dart';

class AlarmScreen extends StatefulWidget {
  final String username;
  final String locationId;
  final String countryId;
  final String cityId;

  const AlarmScreen({
    super.key,
    required this.username,
    required this.locationId,
    required this.countryId,
    required this.cityId,
  });

  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingScreen(context);
    });
  }

  Future<void> _showOnboardingScreen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool shouldShow = prefs.getBool('show_alarm_boarding') ?? true;

    if (shouldShow) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InfoAlarmScreen(),
        ),
      );
      await prefs.setBool('show_alarm_boarding', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localization.translate('alarm_recording') ?? 'Alarm Recording',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localization.translate('coming_soon') ?? 'Coming Soon!',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                localization.translate('coming_soon_message') ??
                    'Stay tuned, more features are on the way.',
                style: const TextStyle(
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
