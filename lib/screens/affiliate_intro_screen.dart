import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import 'affiliate_existing_login_screen.dart';
import 'affiliate_register_screen.dart';

class AffiliateIntroScreen extends StatelessWidget {
  const AffiliateIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.translate('affiliate_welcome_title') ?? 'Postani partner',
        ),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.translate('affiliate_welcome_text') ??
                  'Dobro došli u Conexa Affiliate program! Kao naš partner dobivate ...',
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(),

            // Za postojeće Conexa korisnike
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AffiliateExistingLoginScreen()),
                );
              },
              child: Text(
                loc.translate('affiliate_already_registered') ??
                    'Već sam registrirani Conexa korisnik',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Za nove korisnike
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AffiliateRegisterScreen()),
                );
              },
              child: Text(
                loc.translate('affiliate_new_registration') ??
                    'Želim postati novi korisnik i partner',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
