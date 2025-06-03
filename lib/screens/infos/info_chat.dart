import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';

class ChatOnboardingScreen extends StatelessWidget {
  const ChatOnboardingScreen({super.key});

  Future<void> _disableFuturePopups(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_chat_onboarding', false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('chatOnboardingTitle') ??
            'Dobrodošli u Chat'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Image.asset(
                  'assets/images/info_chat.png',
                  height: 200,
                ),
                const SizedBox(height: 20),
                Text(
                  localizationService.translate('chatOnboardingWelcome') ??
                      'Dobrodošli u našu chat zajednicu!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  localizationService.translate('chatOnboardingDescription') ??
                      'Ovdje možete dijeliti poruke, slike i komentare sa svojim susjedima.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _disableFuturePopups(context),
                  child: Text(localizationService.translate('dontShowAgain') ??
                      'Ne prikazuj više'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      Text(localizationService.translate('close') ?? 'Zatvori'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
