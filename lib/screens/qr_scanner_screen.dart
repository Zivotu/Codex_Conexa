import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Koristimo mobile_scanner
import 'location_details_screen.dart'; // Pretpostavljamo da ovo postoji
import '../services/location_service.dart';
import '../services/user_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String username;

  const QRScannerScreen({super.key, required this.username});

  @override
  QRScannerScreenState createState() => QRScannerScreenState();
}

class QRScannerScreenState extends State<QRScannerScreen> {
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();
  bool _isProcessing = false;

  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (BarcodeCapture capture) async {
          if (!_isProcessing) {
            _isProcessing = true;
            // Dohvatimo prvi barcode iz liste
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? qrCode = barcodes.first.rawValue;
              // U produkciji koristite logging framework umjesto print
              print('QR code scanned: $qrCode');
              if (qrCode != null) {
                await _processQRCode(qrCode);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Neispravan QR kod')),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Neispravan QR kod')),
              );
            }
            _isProcessing = false;
          }
        },
      ),
    );
  }

  Future<void> _processQRCode(String qrCode) async {
    final Uri? uri = Uri.tryParse(qrCode);

    if (uri != null && uri.pathSegments.length >= 3) {
      // Pretpostavljamo URI strukturu: /{nesto}/{countryId}/{cityId}/{locationId}
      final countryId = uri.pathSegments[1];
      final cityId = uri.pathSegments[2];
      final locationId = uri.pathSegments.length > 3 ? uri.pathSegments[3] : '';

      if (countryId.isEmpty || cityId.isEmpty || locationId.isEmpty) {
        print(
            'One of the ID fields is empty: countryId: $countryId, cityId: $cityId, locationId: $locationId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR kod sadrži neispravne podatke.')),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        try {
          final locationData = await _locationService.getLocationDocument(
            countryId,
            cityId,
            locationId,
          );

          if (locationData != null && !locationData['deleted']) {
            final locationName = locationData['name'] ?? 'Unnamed Location';

            // 1. Provjera postoji li lokacija već u korisničkim podacima
            final userData = await _userService.getUserDocument(user);
            final List<dynamic> userLocations = userData?['locations'] ?? [];

            final existingLocation = userLocations.firstWhere(
              (loc) => loc['locationId'] == locationId,
              orElse: () => null,
            );

            if (existingLocation != null &&
                existingLocation['status'] != 'left') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Već ste član ove lokacije')),
              );
              return;
            }

            // 2. Ako je lokacija napuštena, ažuriraj status na "joined"
            if (existingLocation != null &&
                existingLocation['status'] == 'left') {
              await _userService.updateUserDocument(user, {
                'locations': FieldValue.arrayRemove([existingLocation])
              });
            }

            // 3. Dodavanje lokacije korisniku
            await _userService.updateUserDocument(user, {
              'locations': FieldValue.arrayUnion([
                {
                  'locationId': locationId,
                  'locationName': locationName,
                  'joinedAt': Timestamp.fromDate(DateTime.now()),
                  'countryId': countryId,
                  'cityId': cityId,
                  'locationAdmin': false,
                  'status': 'joined',
                  'deleted': false,
                }
              ]),
            });

            // 4. Ažuriranje kolekcije 'user_locations'
            await FirebaseFirestore.instance
                .collection('user_locations')
                .doc(user.uid)
                .collection('locations')
                .doc(locationId)
                .set({
              'locationId': locationId,
              'locationName': locationName,
              'countryId': countryId,
              'cityId': cityId,
              'joinedAt': Timestamp.fromDate(DateTime.now()),
              'locationAdmin': false,
              'deleted': false,
              'status': 'joined',
            });

            // 5. Dodavanje korisnika u 'location_users' kolekciju
            final displayName = userData?['displayName'] ?? 'Unknown';
            final email = userData?['email'] ?? '';
            final profileImageUrl = userData?['profileImageUrl'] ?? '';

            await FirebaseFirestore.instance
                .collection('location_users')
                .doc(locationId)
                .collection('users')
                .doc(user.uid)
                .set({
              'userId': user.uid,
              'username': widget.username,
              'displayName': displayName,
              'email': email,
              'profileImageUrl': profileImageUrl,
              'joinedAt': Timestamp.fromDate(DateTime.now()),
              'deleted': false,
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Uspješno pridruživanje lokaciji')),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationDetailsScreen(
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                    username: widget.username,
                    displayName: locationName,
                    locationAdmin: false,
                  ),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Lokacija ne postoji ili je obrisana.')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neispravan link iz QR koda')),
      );
    }
  }
}
