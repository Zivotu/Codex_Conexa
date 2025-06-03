import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';

class InfoBulletinScreen extends StatelessWidget {
  const InfoBulletinScreen({super.key});

  Future<void> _disableFuturePopups(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_bulletin_onboarding', false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('bulletinOnboardingTitle') ??
            'Dobrodošli na Oglasnu ploču'),
        automaticallyImplyLeading: false, // Uklanja back gumb
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Image.asset(
                  'assets/images/info_bulletin.png', // Osiguraj da postoji ova slika
                  height: 200,
                ),
                const SizedBox(height: 20),
                Text(
                  localizationService.translate('bulletinOnboardingWelcome') ??
                      'Dobrodošli na Oglasnu ploču',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  localizationService
                          .translate('bulletinOnboardingDescription') ??
                      'Ovdje možete pregledavati oglase, dijeliti informacije i ostavljati komentare.',
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
