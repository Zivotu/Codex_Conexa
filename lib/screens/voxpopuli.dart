import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoxPopuliScreen extends StatefulWidget {
  const VoxPopuliScreen({super.key});

  @override
  _VoxPopuliScreenState createState() => _VoxPopuliScreenState();
}

class _VoxPopuliScreenState extends State<VoxPopuliScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // Funkcija za slanje podataka u Firestore
  Future<void> _sendFeedback() async {
    final String message = _messageController.text;
    final String? name =
        _nameController.text.isNotEmpty ? _nameController.text : null;
    final String? contact =
        _contactController.text.isNotEmpty ? _contactController.text : null;

    if (message.isEmpty) {
      // Ako nema poruke, upozori korisnika
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poruka ne smije biti prazna!')),
      );
      return;
    }

    // Dohvati trenutno prijavljenog korisnika
    final User? user = FirebaseAuth.instance.currentUser;

    // Spremi podatke u Firestore, uključujući id korisnika i URL profilne slike
    await FirebaseFirestore.instance.collection('voxpopuli_hr').add({
      'message': message,
      'name': name,
      'contact': contact,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': user?.uid, // dodan korisnički ID
      'profilePic': user?.photoURL, // dodan URL profilne slike
    });

    // Očisti polja nakon slanja
    _messageController.clear();
    _nameController.clear();
    _contactController.clear();

    // Prikaz poruke o uspjehu s povratkom na prethodni ekran
    _showThankYouDialog();
  }

  // Funkcija za prikaz zahvalnog dijaloga
  Future<void> _showThankYouDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hvala vam!'),
          content: const Text(
              'Vaša poruka je uspješno poslana. Zahvaljujemo vam na vašem vremenu i trudu. '
              'Vaša povratna informacija nam je iznimno važna.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Zatvori dijalog
                Navigator.of(context)
                    .pop(); // Vrati korisnika na prethodni ekran
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaši komentari, savjeti i upiti'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veliko polje za unos poruke
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Unesite vašu poruku',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            // Polje za unos imena i prezimena
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ime i prezime (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            // Polje za unos kontakta
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Kontakt (opcionalno)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            // Gumb za slanje poruke
            Center(
              child: ElevatedButton(
                onPressed: _sendFeedback,
                child: const Text('Pošalji'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
