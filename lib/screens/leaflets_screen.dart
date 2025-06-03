import 'package:flutter/material.dart';

class LeafletsScreen extends StatelessWidget {
  const LeafletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letci'),
      ),
      body: const Center(
        child: Text('Ovdje možete pregledati letke!'),
      ),
    );
  }
}
