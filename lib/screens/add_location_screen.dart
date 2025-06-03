import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class AddLocationScreen extends StatefulWidget {
  final String username;

  const AddLocationScreen({super.key, required this.username});

  @override
  AddLocationScreenState createState() => AddLocationScreenState();
}

class AddLocationScreenState extends State<AddLocationScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final List<String> _predefinedLocations = [
    'Trnsko',
    'Siget',
    'Utrine',
    'Trešnjevka',
    'Zapruđe',
    'Dubrava',
    'Centar',
    'Kajzerica',
    'Gornji Grad'
  ];

  Future<void> _addLocation() async {
    try {
      const countryId = 'country_id'; // Zamijeniti stvarnim country ID
      const cityId = 'city_id'; // Zamijeniti stvarnim city ID

      final userDoc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      final userLocations = List<String>.from(userDoc['locations'] ?? []);

      if (userLocations.length >= _predefinedLocations.length) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.instance.translate('all_locations_added') ??
                    'All locations already added.',
              ),
            ),
          );
        }
        return;
      }

      final nextLocation = _predefinedLocations[userLocations.length];
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'locations': FieldValue.arrayUnion([nextLocation]),
      });

      await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(nextLocation)
          .update({
        'users': FieldValue.arrayUnion([currentUser!.uid]),
      });

      if (mounted) {
        Navigator.pop(context, true); // Signalizira uspješno dodavanje
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${LocalizationService.instance.translate('error_adding_location') ?? 'Error adding location'}: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('add_location') ?? 'Add Location',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addLocation,
              child: Text(
                localizationService.translate('add_location') ?? 'Add Location',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
