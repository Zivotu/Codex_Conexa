import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/user_service.dart';

class AdminVoxPopuliScreen extends StatefulWidget {
  final String locationId;
  final String locationName;
  const AdminVoxPopuliScreen({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  _AdminVoxPopuliScreenState createState() => _AdminVoxPopuliScreenState();
}

class _AdminVoxPopuliScreenState extends State<AdminVoxPopuliScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String? displayName;

  @override
  void initState() {
    super.initState();
    _fetchDisplayName();
  }

  Future<void> _fetchDisplayName() async {
    // Pokušavamo dohvatiti displayName iz FirebaseAuth-a
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      setState(() {
        displayName = user.displayName;
      });
    } else {
      // Ako displayName nije postavljen, pokušavamo dohvatiti korisnički dokument iz Firestorea
      final userServiceInstance = UserService();
      final userData = await userServiceInstance.getUserDocument(user!);
      setState(() {
        displayName = userData?['displayName'] ?? 'Nepoznati administrator';
      });
    }
  }

  Future<void> _sendFeedback() async {
    final String message = _messageController.text.trim();
    final String? contact = _contactController.text.trim().isNotEmpty
        ? _contactController.text.trim()
        : null;

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poruka ne smije biti prazna!')),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    // Spremanje poruke u kolekciju 'administrators_vox_populi'
    await FirebaseFirestore.instance
        .collection('administrators_vox_populi')
        .add({
      'message': message,
      'contact': contact,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': user?.uid,
      'displayName': displayName,
      'locationId': widget.locationId,
      'locationName': widget.locationName,
      'profilePic': user?.photoURL,
    });

    _messageController.clear();
    _contactController.clear();

    _showThankYouDialog();
  }

  Future<void> _showThankYouDialog() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizationService.translate('admin_vox_populi_header') ??
            'Administrator Feedback'),
        content: Text(
            localizationService.translate('admin_vox_populi_description') ??
                'Vaša poruka je uspješno poslana.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Zatvori dijalog
              Navigator.of(context).pop(); // Vrati korisnika na prethodni ekran
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('admin_vox_populi_header') ??
            'Administrator Feedback'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tekst na vrhu ekrana koji objašnjava svrhu ovog modula
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  localizationService.translate('admin_module_info') ??
                      'Ovaj modul je namijenjen isključivo za administratore lokacija. Ovdje možete poslati direktan upit, prijedlog, komentar ili zahtjev razvojnom timu Conexe.',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              // Prikaz lokacije (nepromjenjivo)
              Text(
                '${localizationService.translate('location') ?? 'Lokacija'}: ${widget.locationName}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              // Prikaz imena administratora (nepromjenjivo)
              Text(
                '${localizationService.translate('admin') ?? 'Administrator'}: ${displayName ?? 'Nepoznato'}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Polje za unos poruke
              TextField(
                controller: _messageController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: localizationService.translate('message_hint') ??
                      'Unesite vašu poruku',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Polje za unos kontakta (opcionalno)
              TextField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: localizationService.translate('contact_hint') ??
                      'Kontakt (opcionalno)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _sendFeedback,
                  child: Text(localizationService.translate('send_button') ??
                      'Pošalji'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
