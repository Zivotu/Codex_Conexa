// lib/screens/affiliate_existing_login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../services/localization_service.dart';
import 'affiliate_supplement_screen.dart';

class AffiliateExistingLoginScreen extends StatefulWidget {
  const AffiliateExistingLoginScreen({super.key});

  @override
  _AffiliateExistingLoginScreenState createState() =>
      _AffiliateExistingLoginScreenState();
}

class _AffiliateExistingLoginScreenState
    extends State<AffiliateExistingLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _loading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _log = Logger();

  Future<void> _login() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      final user = cred.user!;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final hasCode = (await FirebaseFirestore.instance
              .collection('affiliate_bonus_codes')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get())
          .docs
          .isNotEmpty;

      final loc = Provider.of<LocalizationService>(context, listen: false);

      // Sad provjeravamo novo polje 'affiliateActive'
      if (doc.data()?['affiliateActive'] == true && hasCode) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              loc.translate('affiliate_already_partner') ??
                  'Već ste naš partner!',
            ),
            content: Text(
              loc.translate('affiliate_already_partner_info') ??
                  'U izborniku “Partneri” možete vidjeti sve detalje.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(loc.translate('ok') ?? 'OK'),
              )
            ],
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Nismo još označeni kao aktivni affiliate → otvaramo kompletan obrazac
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AffiliateSupplementScreen(userId: user.uid),
          ),
        );
      }
    } catch (e) {
      _log.e('Affiliate login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Neuspješna prijava: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('login') ?? 'Prijava'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: loc.translate('email') ?? 'Email',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: loc.translate('password') ?? 'Lozinka',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(loc.translate('next') ?? 'Dalje'),
            ),
          ],
        ),
      ),
    );
  }
}
