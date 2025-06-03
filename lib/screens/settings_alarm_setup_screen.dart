import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsAlarmSetupScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const SettingsAlarmSetupScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  SettingsAlarmSetupScreenState createState() =>
      SettingsAlarmSetupScreenState();
}

class SettingsAlarmSetupScreenState extends State<SettingsAlarmSetupScreen> {
  final _pinController = TextEditingController();
  bool _alarmEnabled = true; // Zadano postavljeno na true
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _pinController.text = data?['alarmPin'] ?? '';
        _alarmEnabled = data?['alarmEnabled'] ?? true;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN is required')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'alarmPin': _pinController.text,
        'alarmEnabled': _alarmEnabled,
      });
    }

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Setup'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'Alarm PIN',
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: false, // PIN je vidljiv
                  ),
                  SwitchListTile(
                    title: const Text('Enable Alarm Notifications'),
                    value: _alarmEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _alarmEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
    );
  }
}
