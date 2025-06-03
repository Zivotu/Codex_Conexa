// lib/screens/delete_location_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import 'package:provider/provider.dart';

class DeleteLocationConfirmationScreen extends StatelessWidget {
  final String locationId;
  final String locationName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const DeleteLocationConfirmationScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.onConfirm,
    required this.onCancel,
  });

  Future<void> _deleteLocation(BuildContext context) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('user_not_logged_in') ??
              'You must be logged in.'),
        ),
      );
      return;
    }
    try {
      final locationRef =
          FirebaseFirestore.instance.collection('locations').doc(locationId);
      final allLocRef = FirebaseFirestore.instance
          .collection('all_locations')
          .doc(locationId);
      final userOwnedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('owned_locations')
          .doc(locationId);
      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(user.uid)
          .collection('locations')
          .doc(locationId);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(locationRef, {'deleted': true});
      batch.update(allLocRef, {'deleted': true});
      batch.update(userOwnedRef, {'deleted': true});
      batch.update(userLocationRef, {'deleted': true});
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              localizationService.translate('location_deleted_success') ??
                  'Location deleted successfully.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${localizationService.translate('error_deleting_location') ?? 'Error deleting location'}: $e'),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final confirmationMessage = localizationService
        .translate('delete_confirmation_message')
        .replaceAll('{locationName}', locationName);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService
                .translate('delete_location_confirmation_title') ??
            'Delete Location Confirmation'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 100, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                confirmationMessage,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _deleteLocation(context);
                      onConfirm();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: Text(
                      localizationService.translate('yes_delete') ??
                          'Yes, delete',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      onCancel();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white),
                    child: Text(
                      localizationService.translate('cancel') ?? 'Cancel',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
