import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'user_locations_screen.dart';
import '../services/localization_service.dart';

class ReviewLocationScreen extends StatelessWidget {
  final String locationId;
  final String locationName;
  final String locationAddress;
  final String city;
  final String country;
  final int year;
  final String selectedImagePath;
  final VoidCallback onConfirm;
  final String username;
  final String activationType; // tip aktivacije ("trial" ili "active")
  final String? activeUntil; // datum isteka aktivacije kao string
  final String? creditId; // NOVO: ID kredita ako je dodijeljen

  const ReviewLocationScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.locationAddress,
    required this.city,
    required this.country,
    required this.year,
    required this.selectedImagePath,
    required this.onConfirm,
    required this.username,
    required this.activationType,
    this.activeUntil,
    this.creditId,
  });

  @override
  Widget build(BuildContext context) {
    final Logger logger = Logger();
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    bool isNetworkImage = selectedImagePath.startsWith('http');

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('review_location_title')),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Prikaz slike
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isNetworkImage
                  ? Image.network(
                      selectedImagePath,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.teal),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            localizationService.translate('image_load_failed'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      selectedImagePath,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(height: 20),
            // Detalji lokacije
            ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(locationName),
              subtitle: Text('$locationAddress, $city, $country'),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('${localizationService.translate('year')}: $year'),
              subtitle:
                  activeUntil != null ? Text('Aktivno do: $activeUntil') : null,
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Tip aktivacije'),
              subtitle: Text(activationType),
            ),
            const SizedBox(height: 10),
            // NOVO: Ako je kredit dodijeljen, prikazati njegov ID
            if (creditId != null)
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Kredit ID'),
                subtitle: Text(creditId!),
              ),
            const SizedBox(height: 30),
            // Gumb potvrde
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  logger.i('Confirming location creation.');
                  onConfirm();
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                          localizationService.translate('congratulations')),
                      content: Text(
                        localizationService
                            .translate('location_created_message'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(localizationService.translate('ok')),
                        ),
                      ],
                    ),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserLocationsScreen(username: username),
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: Text(localizationService.translate('confirm')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
