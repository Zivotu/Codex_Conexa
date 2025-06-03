import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';

class InfoNoticesScreen extends StatelessWidget {
  const InfoNoticesScreen({super.key});

  Future<void> _disableFuturePopups(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_notices_boarding', false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('infoNoticesTitle') ??
            'O Obavijestima'),
        automaticallyImplyLeading: false, // Uklanja back gumb
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Image.asset(
                            'assets/images/info_notices.png',
                            height: constraints.maxHeight * 0.3,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            localizationService
                                    .translate('infoNoticesWelcome') ??
                                'Dobrodošli u Obavijesti',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            localizationService
                                    .translate('infoNoticesDescription') ??
                                'Ovdje možete pregledavati najnovije obavijesti, komentirati i dijeliti informacije sa svojim susjedima.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _disableFuturePopups(context),
                            child: Text(localizationService
                                    .translate('dontShowAgain') ??
                                'Ne prikazuj više'),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                                localizationService.translate('close') ??
                                    'Zatvori'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
