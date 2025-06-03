// lib/screens/post_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'servicer_dashboard_screen.dart';
import 'user_locations_screen.dart';

class PostRegistrationScreen extends StatelessWidget {
  const PostRegistrationScreen({super.key});

  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      // Handle error if needed
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Registracija Završena'),
        ),
        body: const Center(
          child: Text('Korisnik nije prijavljen.'),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserData(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Registracija Završena'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Registracija Završena'),
            ),
            body: const Center(
                child: Text('Nema dostupnih podataka o korisniku.')),
          );
        }

        final userData = snapshot.data!;

        String username = userData['username'] ?? '';
        String countryId = userData['countryId'] ?? '';
        String cityId = userData['cityId'] ?? '';
        String locationId = userData['locationId'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Registracija Završena'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Za servisere',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserLocationsScreen(
                          username: username,
                        ),
                      ),
                    );
                  },
                  child: const Text('Conexa'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ServicerDashboardScreen(
                          username: username,
                        ),
                      ),
                    );
                  },
                  child: const Text('ConexaPro'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
