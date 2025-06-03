// lib/screens/join_location_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import 'package:conexa/screens/user_locations_screen.dart';

class JoinLocationScreen extends StatefulWidget {
  final String? countryId;
  final String? cityId;
  final String? locationId;

  const JoinLocationScreen({
    super.key,
    this.countryId,
    this.cityId,
    this.locationId,
  });

  @override
  JoinLocationScreenState createState() => JoinLocationScreenState();
}

class JoinLocationScreenState extends State<JoinLocationScreen> {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isLoading = false;
  bool _showScanner = false;
  bool _showManualInput = false;
  final TextEditingController _codeController = TextEditingController();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _logger.d(
        'JoinLocationScreen initState - countryId: ${widget.countryId}, cityId: ${widget.cityId}, locationId: ${widget.locationId}');
    if (widget.countryId != null &&
        widget.cityId != null &&
        widget.locationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showJoinConfirmation(
          countryId: widget.countryId!,
          cityId: widget.cityId!,
          locationId: widget.locationId!,
        );
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    if (_showManualInput) {
      return _buildManualCodeInput();
    }
    if (_showScanner) {
      return _buildQRScannerScreen();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('join_location_appbar_title') ??
              'Join Location',
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              localizationService.translate('join_location_description') ??
                  'Join location by scanning a QR code or entering the code manually.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showScanner = true;
                });
              },
              icon: const Icon(
                Icons.qr_code,
                color: Colors.white,
                size: 32,
              ),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  localizationService.translate('scan_qr_code') ??
                      'Scan QR Code',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(200, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showManualInput = true;
                });
              },
              icon: const Icon(
                Icons.keyboard,
                color: Colors.white,
                size: 32,
              ),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  localizationService.translate('enter_code_manually') ??
                      'Enter Code Manually',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(200, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScannerScreen() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('scan_qr_code') ?? 'Scan QR Code',
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  localizationService.translate('qr_scan_instructions') ??
                      'Scan a QR code to join the location.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: (BarcodeCapture capture) async {
                    final barcode = capture.barcodes.first;
                    if (!_isProcessing && barcode.rawValue != null) {
                      _isProcessing = true;
                      final code = barcode.rawValue!;
                      _logger.i('QR code scanned: $code');
                      await _processQRCode(code);
                      _isProcessing = false;
                    }
                  },
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualCodeInput() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('enter_location_code') ??
              'Enter Location Code',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showManualInput = false;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: localizationService.translate('location_code') ??
                    'Location Code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final code = _codeController.text.trim();
                if (code.isNotEmpty) {
                  await _processQRCode(code);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        localizationService.translate('invalid_code') ??
                            'Please enter a valid code',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                localizationService.translate('join_with_code') ??
                    'Join with Code',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processQRCode(String qrCode) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final Uri? uri = Uri.tryParse(qrCode);
    _logger.i('Parsed URI from QR code/manual input: $uri');
    if (uri == null) {
      _logger.w('Scanned/input code is not a valid URI.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('invalid_qr_code') ??
                'Invalid QR code or code.',
          ),
        ),
      );
      return;
    }
    if (uri.host == 'conexajoin.page.link') {
      _logger.i('Processing Firebase Dynamic Link.');
      try {
        final PendingDynamicLinkData? dynamicLinkData =
            await FirebaseDynamicLinks.instance.getDynamicLink(uri);
        final Uri? deepLink = dynamicLinkData?.link;
        _logger.i('Resolved deep link: $deepLink');
        if (deepLink != null &&
            deepLink.host == 'conexa.life' &&
            deepLink.path == '/join') {
          final countryId = deepLink.queryParameters['countryId'];
          final cityId = deepLink.queryParameters['cityId'];
          final locationId = deepLink.queryParameters['locationId'];
          if (countryId != null && cityId != null && locationId != null) {
            await _showJoinConfirmation(
              countryId: countryId,
              cityId: cityId,
              locationId: locationId,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localizationService
                          .translate('invalid_link_missing_params') ??
                      'Invalid link. Missing parameters.',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizationService.translate('invalid_dynamic_link') ??
                    'Invalid dynamic link.',
              ),
            ),
          );
        }
      } catch (e) {
        _logger.e('Error processing dynamic link: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizationService.translate('error_processing_dynamic_link') ?? 'Error processing dynamic link'}: $e',
            ),
          ),
        );
      }
    } else if (uri.host == 'conexa.life' && uri.path == '/join') {
      final countryId = uri.queryParameters['countryId'];
      final cityId = uri.queryParameters['cityId'];
      final locationId = uri.queryParameters['locationId'];
      if (countryId != null && cityId != null && locationId != null) {
        await _showJoinConfirmation(
          countryId: countryId,
          cityId: cityId,
          locationId: locationId,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('invalid_link_missing_params') ??
                  'Invalid link. Missing parameters.',
            ),
          ),
        );
      }
    } else if (uri.host == 'conexa.life' &&
        uri.pathSegments.length >= 4 &&
        uri.pathSegments[0] == 'locations') {
      final countryId = uri.pathSegments[1];
      final cityId = uri.pathSegments[2];
      final locationId = uri.pathSegments[3];
      if (countryId.isNotEmpty && cityId.isNotEmpty && locationId.isNotEmpty) {
        await _showJoinConfirmation(
          countryId: countryId,
          cityId: cityId,
          locationId: locationId,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('invalid_link_missing_params') ??
                  'Invalid link. Missing parameters.',
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('invalid_link_format') ??
                'Invalid link format.',
          ),
        ),
      );
    }
  }

  Future<void> _showJoinConfirmation({
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            localizationService.translate('join_confirmation_title') ??
                'Join Confirmation',
          ),
          content: Text(
            localizationService.translate('join_confirmation_message') ??
                'Do you want to join this location?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizationService.translate('no') ?? 'No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizationService.translate('yes') ?? 'Yes'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _joinLocation(
        countryId: countryId,
        cityId: cityId,
        locationId: locationId,
      );
    } else {
      _logger.i('User cancelled joining the location.');
    }
  }

  Future<void> _joinLocation({
    required String countryId,
    required String cityId,
    required String locationId,
  }) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    setState(() {
      _isLoading = true;
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(localizationService.translate('user_not_logged_in') ??
            'User not logged in');
      }
      final userId = currentUser.uid;
      final locationDoc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();
      if (!locationDoc.exists || locationDoc.data() == null) {
        throw Exception(localizationService.translate('location_not_found') ??
            'Location not found');
      }
      final locData = locationDoc.data()!;
      final bool isAdmin = locData['ownedBy'] == userId;
      final String activationType = locData['activationType'] ?? 'inactive';
      final Timestamp? activeUntilTs = locData['activeUntil'];
      bool isExpired = false;
      if (activeUntilTs != null) {
        isExpired = activeUntilTs.toDate().isBefore(DateTime.now());
      }
      if (!isAdmin) {
        final bool isSuperAllowed = locData['superAllow'] ?? false;
        final bool isLocationActive = isSuperAllowed
            ? true
            : ((activationType == 'active' ||
                    activationType == 'trialActive') &&
                !isExpired);
        if (!isLocationActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizationService.translate('location_inactive_message') ??
                    'Location is inactive.',
              ),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .collection('locations')
          .doc(locationId);
      final userLocationSnapshot = await userLocationRef.get();
      if (userLocationSnapshot.exists) {
        final status = userLocationSnapshot.data()?['status'];
        if (status == 'kicked') {
          await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(localizationService.translate('blocked_title') ??
                    'Blocked'),
                content: Text(
                  localizationService.translate('cannotJoinKicked') ??
                      'You have been kicked from this location. Please contact the administrator.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localizationService.translate('ok') ?? 'OK'),
                  ),
                ],
              );
            },
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      final locationUserRef = FirebaseFirestore.instance
          .collection('location_users')
          .doc(locationId)
          .collection('users')
          .doc(userId);
      final Map<String, dynamic> locationData = {
        'countryId': countryId,
        'cityId': cityId,
        'locationId': locationId,
        'deleted': false,
        'joinedAt': FieldValue.serverTimestamp(),
        'locationAdmin': false,
        'status': 'joined',
        'displayName': currentUser.displayName ??
            localizationService.translate('unknown_user') ??
            'Unknown User',
        'email': currentUser.email ?? '',
        'profileImageUrl': userLocationSnapshot.data()?['profileImageUrl'] ??
            'assets/images/default_user.png',
        'fcmToken': '',
        'userId': userId,
      };
      if (userLocationSnapshot.exists &&
          userLocationSnapshot.data()?['status'] == 'left') {
        await userLocationRef.update(locationData);
        await locationUserRef.update(locationData);
        _logger.i('User rejoined the location.');
      } else {
        await userLocationRef.set(locationData);
        await locationUserRef.set(locationData);
        _logger.i('User joined the location for the first time.');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              localizationService.translate('location_joined_success') ??
                  'Location joined successfully.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const UserLocationsScreen(username: 'User'),
        ),
      );
    } catch (e) {
      _logger.e('Error joining location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('error_joining_location') ?? 'Error joining location'}: $e',
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
