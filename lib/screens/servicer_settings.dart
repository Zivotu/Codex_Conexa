import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'servicerpayment.dart';

class ServicerSettings extends StatelessWidget {
  final String username;

  const ServicerSettings({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviser Postavke'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Sustav naplate'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ServicerPaymentScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Odjavi se'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (Route<dynamic> route) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}
