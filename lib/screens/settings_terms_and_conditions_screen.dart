import 'package:flutter/material.dart';

class SettingsTermsAndConditionsScreen extends StatelessWidget {
  const SettingsTermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Your terms and conditions text here...',
        ),
      ),
    );
  }
}
