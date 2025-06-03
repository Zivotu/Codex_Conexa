// lib/screens/location_settings_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'users_screen.dart';
import 'user_locations_screen.dart';
import 'edit_location_screen.dart';
import 'payment_dashboard_screen.dart';
import '../services/location_service.dart';
import '../services/localization_service.dart';
import '../services/subscription_service.dart';
import '../services/location_activation_service.dart';
import 'delete_location_confirmation_screen.dart';
import 'module_settings_screen.dart';

class LocationSettingsScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final bool locationAdmin;

  const LocationSettingsScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationAdmin,
  });

  @override
  _LocationSettingsScreenState createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  String _locationName = '';
  String _locationAddress = '';
  String _locationImageUrl = '';
  String _locationLink = '';

  bool _isLocationAdmin = false;
  bool _requiresApproval = false; // polje koje očitavamo i mijenjamo

  final LocationService _locationService = LocationService();
  final Logger _logger = Logger();
  final LocationActivationService _locationActivationService =
      LocationActivationService();

  String _dynamicLink = '';
  bool _isGeneratingLink = true;

  // Ostale varijable i mapirane postavke
  final Map<String, bool> _enabledModules = {
    'officialNotices': true,
    'chatRoom': true,
    'quiz': true,
    'bulletinBoard': true,
    'parkingCommunity': true,
    'wiseOwl': true,
    'snowCleaning': true,
    'security': true,
    'alarm': true,
    'noise': true,
    'readings': true,
  };

  List<Admin> _administrators = [];
  bool _isLoadingAdmins = true;

  DateTime? _activeUntil;
  String _activationType = "";
  bool _trialPeriod = false;

  Map<String, dynamic>? _currentSubscription;

  @override
  void initState() {
    super.initState();
    _fetchLocationData();
    _checkIfAdmin();
    _fetchAdministrators();
    _checkAndRefreshSubscriptionStatus();
    _fetchCurrentSubscriptionData();
  }

  Future<void> _fetchCurrentSubscriptionData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final subscriptionDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Subscriptions')
        .doc('current')
        .get();
    if (subscriptionDoc.exists) {
      setState(() {
        _currentSubscription = subscriptionDoc.data();
      });
    }
  }

  Future<void> _fetchLocationData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .get();

      if (doc.exists) {
        final localizationService = Provider.of<LocalizationService>(
          context,
          listen: false,
        );
        final data = doc.data()!;
        setState(() {
          _locationName = data['name'] ??
              localizationService.translate('unknownLocationName') ??
              'Unknown Location Name';
          _locationAddress = data['address'] ??
              localizationService.translate('unknownAddress') ??
              'Unknown Address';
          _locationImageUrl = data['imagePath'] ?? '';
          _locationLink = widget.locationId;
          _requiresApproval = data['requiresApproval'] ?? false;

          final Timestamp? ts = data['activeUntil'];
          if (ts != null) {
            _activeUntil = ts.toDate();
          }
          _activationType = data['activationType'] ?? "";
          _trialPeriod = data['trialPeriod'] ?? false;
        });

        _dynamicLink = await _createDynamicLink(
          widget.countryId,
          widget.cityId,
          widget.locationId,
        );
      }
    } catch (e) {
      _logger.e('Error fetching location data: $e');
      final localizationService = Provider.of<LocalizationService>(
        context,
        listen: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('errorFetchingLocationData') ??
                'Error fetching location data: $e',
          ),
        ),
      );
    } finally {
      setState(() {
        _isGeneratingLink = false;
      });
    }
  }

  Future<void> _checkAndRefreshSubscriptionStatus() async {
    final subscriptionService = Provider.of<SubscriptionService>(
      context,
      listen: false,
    );
    await subscriptionService.loadCurrentSubscription();
    bool isActiveSub = await subscriptionService.hasActiveSubscription();
    final DateTime? subEndDate =
        subscriptionService.getCurrentSubscriptionEndDate();

    final docRef = FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.locationId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    String actType = data['activationType'] ?? '';
    DateTime? locEnd;
    final Timestamp? ts = data['activeUntil'];
    if (ts != null) {
      locEnd = ts.toDate();
    }

    if (!isActiveSub) {
      actType = 'inactive';
      locEnd = null;
    } else if (isActiveSub &&
        (actType == 'trial' || actType == 'trialexpired')) {
      if (subEndDate != null && subEndDate.isAfter(DateTime.now())) {
        actType = 'active';
        locEnd = subEndDate;
      }
    }

    setState(() {
      _activationType = actType;
      _activeUntil = locEnd;
    });
  }

  Future<String> _createDynamicLink(
    String countryId,
    String cityId,
    String locationId,
  ) async {
    final String deepLink =
        'https://conexa.life/join?countryId=$countryId&cityId=$cityId&locationId=$locationId';
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://conexaJoin.page.link',
      link: Uri.parse(deepLink),
      androidParameters: const AndroidParameters(
        packageName: 'dreamteamstudio.online.conexa',
        minimumVersion: 0,
      ),
      iosParameters: const IOSParameters(
        bundleId: 'com.yourcompany.conexa',
        minimumVersion: '0',
      ),
    );
    final ShortDynamicLink shortLink =
        await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    return shortLink.shortUrl.toString();
  }

  Future<void> _checkIfAdmin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(currentUser.uid)
            .collection('locations')
            .doc(widget.locationId)
            .get();

        if (doc.exists) {
          setState(() {
            _isLocationAdmin = doc.data()?['locationAdmin'] ?? false;
          });
        }
      }
    } catch (e) {
      _logger.e('Error checking admin status: $e');
    }
  }

  Future<void> _fetchAdministrators() async {
    try {
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('location_users')
          .doc(widget.locationId)
          .collection('users')
          .where('locationAdmin', isEqualTo: true)
          .where('deleted', isEqualTo: false)
          .get();

      List<Admin> admins = [];
      List<Future<Admin?>> adminFutures = adminsSnapshot.docs.map((doc) async {
        String userId = doc.data()['userId'] ?? '';
        if (userId.isEmpty) return null;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            return Admin(
              userId: userId,
              displayName: userData['displayName'] ?? '',
              lastName: userData['lastName'] ?? '',
              phone: userData['phone'] ?? '',
              profileImageUrl: userData['profileImageUrl'] ?? '',
              phoneVisible: userData['phoneVisible'] ?? true,
            );
          } else {
            _logger.w('User document not found for userId: $userId');
            return null;
          }
        } catch (e) {
          _logger.e('Error fetching user data for userId: $userId, Error: $e');
          return null;
        }
      }).toList();

      final fetchedAdmins = await Future.wait(adminFutures);
      admins = fetchedAdmins.whereType<Admin>().toList();
      setState(() {
        _administrators = admins;
        _isLoadingAdmins = false;
      });
    } catch (e) {
      _logger.e('Error fetching administrators: $e');
      setState(() {
        _isLoadingAdmins = false;
      });
      final localizationService = Provider.of<LocalizationService>(
        context,
        listen: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('errorFetchingAdmins') ??
                'Error fetching administrators.',
          ),
        ),
      );
    }
  }

  Widget _buildActivationStatusWidget(LocalizationService localizationService) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            localizationService.translate('error_loading_status') ??
                'Error loading status',
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String actType = data['activationType'] ?? 'inactive';
        final Timestamp? ts = data['activeUntil'];
        DateTime? locEnd = ts?.toDate();
        final now = DateTime.now();
        String statusText = "";
        Widget? actionWidget;

        if (actType == 'active') {
          if (locEnd!.isAfter(now)) {
            final formattedDate =
                "${locEnd.day}.${locEnd.month}.${locEnd.year}";
            statusText =
                "${localizationService.translate('locationActive')} (${localizationService.translate('until')} $formattedDate)";
          } else {
            statusText = localizationService.translate('subscriptionExpired') ??
                "Subscription expired – please renew.";
            actionWidget = ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentDashboardScreen(),
                  ),
                );
              },
              child: Text(
                localizationService.translate('buySubscription') ??
                    'Buy Subscription',
              ),
            );
          }
        } else if (actType == 'trial') {
          if (locEnd!.isAfter(now)) {
            final formattedDate =
                "${locEnd.day}.${locEnd.month}.${locEnd.year}";
            statusText =
                "${localizationService.translate('trialActive')} $formattedDate";
          } else {
            statusText = localizationService.translate('trialExpired') ??
                "Trial expired";
            actionWidget = ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaymentDashboardScreen(),
                  ),
                );
              },
              child: Text(
                localizationService.translate('buySubscription') ??
                    'Buy Subscription',
              ),
            );
          }
        } else if (actType == 'trialexpired') {
          statusText =
              localizationService.translate('trialExpired') ?? "Trial expired";
          actionWidget = ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentDashboardScreen(),
                ),
              );
            },
            child: Text(
              localizationService.translate('buySubscription') ??
                  'Buy Subscription',
            ),
          );
        } else if (actType == 'manualdeactivated') {
          statusText =
              localizationService.translate('locationManualDeactivated') ??
                  "Location is manually deactivated.";
          actionWidget = ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentDashboardScreen(),
                ),
              );
            },
            child: Text(
              localizationService.translate('reactivate') ?? 'Reactivate',
            ),
          );
        } else {
          statusText = localizationService.translate('locationInactive') ??
              "Location is inactive (no subscription/slots)";
          actionWidget = Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentDashboardScreen(),
                    ),
                  );
                },
                child: Text(
                  localizationService.translate('buySubscription') ??
                      'Buy Subscription',
                ),
              ),
            ],
          );
        }

        return Card(
          color:
              (actType == 'active') ? Colors.green.shade50 : Colors.red.shade50,
          child: ListTile(
            leading: Icon(
              (actType == 'active') ? Icons.check_circle : Icons.warning,
              color: (actType == 'active') ? Colors.green : Colors.red,
              size: (actType == 'active') ? 24 : 32,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: (actType == 'active') ? 16 : 18,
                    fontWeight: (actType == 'active')
                        ? FontWeight.normal
                        : FontWeight.bold,
                    color: (actType == 'active') ? Colors.black : Colors.red,
                  ),
                ),
                if (actionWidget != null) ...[
                  const SizedBox(height: 8),
                  actionWidget,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminOptions(LocalizationService localizationService) {
    List<Widget> options = [];

    if (_isLocationAdmin) {
      options.add(
        SwitchListTile(
          title: Text(
            localizationService.translate('lockJoinRequests') ??
                'Zaključaj pridruživanje?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _requiresApproval
                ? (localizationService.translate('lockJoinRequestsOn') ??
                    'Lokacija je zaključana, novi korisnici trebaju odobrenje.')
                : (localizationService.translate('lockJoinRequestsOff') ??
                    'Lokacija je otključana, svi se mogu slobodno pridružiti.'),
          ),
          value: _requiresApproval,
          onChanged: (bool value) async {
            await _toggleRequiresApproval(value);
          },
        ),
      );

      options.addAll([
        ListTile(
          leading: const Icon(Icons.people, size: 30, color: Colors.blueAccent),
          title: Text(
            localizationService.translate('users') ?? 'Users',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsersScreen(
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit, size: 30, color: Colors.orangeAccent),
          title: Text(
            localizationService.translate('editLocation') ?? 'Edit Location',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditLocationScreen(
                  locationId: widget.locationId,
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings, size: 30, color: Colors.blueGrey),
          title: Text(
            localizationService.translate('moduleSettings') ??
                'Module Settings',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleSettingsScreen(
                  countryId: widget.countryId,
                  cityId: widget.cityId,
                  locationId: widget.locationId,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, size: 30, color: Colors.redAccent),
          title: Text(
            localizationService.translate('deleteLocation') ??
                'Delete Location',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onTap: () => _showDeleteConfirmation(context),
        ),
      ]);
    } else {
      options.add(
        ListTile(
          leading: const Icon(Icons.exit_to_app, size: 30, color: Colors.grey),
          title: Text(
            localizationService.translate('leaveLocation') ?? 'Leave Location',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onTap: () => _showLeaveConfirmation(context),
        ),
      );
    }

    return Column(children: options);
  }

  Future<void> _toggleRequiresApproval(bool value) async {
    setState(() {
      _requiresApproval = value;
    });
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .update({'requiresApproval': value});
      _logger.d("requiresApproval updated to $value for ${widget.locationId}");
    } catch (e) {
      _logger.e("Error updating requiresApproval: $e");
      final localizationService = Provider.of<LocalizationService>(
        context,
        listen: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('updateError') ??
                'Failed to update lock setting',
          ),
        ),
      );
    }
  }

  void _toggleAdminPhoneVisibility(
      String userId, bool currentVisibility) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'phoneVisible': !currentVisibility,
      });
      setState(() {
        _administrators = _administrators.map((admin) {
          if (admin.userId == userId) {
            return Admin(
              userId: admin.userId,
              displayName: admin.displayName,
              lastName: admin.lastName,
              phone: admin.phone,
              profileImageUrl: admin.profileImageUrl,
              phoneVisible: !currentVisibility,
            );
          } else {
            return admin;
          }
        }).toList();
      });
      final localizationService = Provider.of<LocalizationService>(
        context,
        listen: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentVisibility
                ? (localizationService.translate('phoneVisibilityEnabled') ??
                    'Phone visibility enabled.')
                : (localizationService.translate('phoneVisibilityDisabled') ??
                    'Phone visibility disabled.'),
          ),
        ),
      );
    } catch (e) {
      _logger.e('Error toggling phone visibility: $e');
      final localizationService = Provider.of<LocalizationService>(
        context,
        listen: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('togglePhoneVisibilityError') ??
                'Error toggling phone visibility.',
          ),
        ),
      );
    }
  }

  /// NOVA IMPLEMENTACIJA _shareLocationLink
  /// Sada se prilikom dijeljenja linka lokacije dijeli i poruka s kratkim uputama.
  void _shareLocationLink(
    BuildContext context,
    String countryId,
    String cityId,
    String locationId,
  ) async {
    try {
      final String dynamicLink = await _createDynamicLink(
        countryId,
        cityId,
        locationId,
      );
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);

      // Dohvatimo osnovnu poruku iz lokalizacije ili koristimo zadani tekst.
      final String baseMessage = localizationService
              .translate('share_location_message') ??
          'Pozivam Vas da se pridružite CONEXA virtualnoj lokaciji i postanete naš novi član zajednice.\n\n'
              'Link u nastavku samo kliknite i odvest će vas na ekran za pridruživanje.\n\n'
              'U slučaju sigurnosnih ograničenja mobitela, manualno kopirajte link u ekranu za pridruživanje unutar same aplikacije.';

      // Sada eksplicitno dodajemo i generirani link na kraj poruke.
      final String shareMessage = '$baseMessage\n\n$dynamicLink';

      Share.share(
        shareMessage,
        subject: localizationService.translate('shareLocationSubject') ??
            'Check out this location on Conexa!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('shareLinkError') ??
                'Error sharing link.',
          ),
        ),
      );
      _logger.e("Error sharing dynamic link: $e");
    }
  }

  Future<Uint8List> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("Failed to download image");
    }
  }

  Future<Uint8List> _generateQRCodeImage(String data) async {
    final qrValidationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );
    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
        ),
        gapless: true,
      );
      final image = await painter.toImage(200);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } else {
      throw Exception('QR Code generation failed');
    }
  }

  Widget _buildLocationImage() {
    if (_locationImageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Image.network(
          _locationImageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/default_location.png',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Image.asset(
          _locationImageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/default_location.png',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    showDialog(
      context: context,
      builder: (context) {
        return DeleteLocationConfirmationScreen(
          locationId: widget.locationId,
          locationName: _locationName,
          onConfirm: _deleteLocation,
          onCancel: () {},
        );
      },
    );
  }

  Future<void> _deleteLocation() async {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await _locationService.deleteLocationForAdmin(
        userId,
        widget.countryId,
        widget.cityId,
        widget.locationId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('locationDeletedSuccessfully') ??
                'Location deleted successfully',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => UserLocationsScreen(username: widget.username),
        ),
        (route) => false,
      );
    } catch (e) {
      _logger.e('Error deleting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('deleteLocationError') ?? 'Error deleting location'}: $e',
          ),
        ),
      );
    }
  }

  void _showLeaveConfirmation(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            localizationService.translate('leaveLocation') ?? 'Leave Location',
          ),
          content: Text(
            localizationService.translate('leaveLocationConfirmation') ??
                'Are you sure you want to leave this location?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizationService.translate('cancel') ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _leaveLocation();
              },
              child: Text(localizationService.translate('leave') ?? 'Leave'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _leaveLocation() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _locationService.leaveLocation(user.uid, widget.locationId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('successfullyLeft') ??
                  'You have successfully left the location.',
            ),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                UserLocationsScreen(username: widget.username),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('userNotLoggedIn') ??
                  'User is not logged in.',
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error leaving location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('leaveLocationError') ?? 'Error leaving location'}: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('locationSettings') ??
              'Location Settings',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildActivationStatusWidget(localizationService),
          _buildAdminOptions(localizationService),
          ListTile(
            leading: const Icon(Icons.share, size: 30, color: Colors.green),
            title: Text(
              localizationService.translate('shareLocationLink') ??
                  'Share location link',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onTap: () => _shareLocationLink(
                context, widget.countryId, widget.cityId, widget.locationId),
          ),
          ListTile(
            leading: const Icon(
              Icons.picture_as_pdf,
              size: 30,
              color: Colors.brown,
            ),
            title: Text(
              localizationService.translate('shareLocationAsPDF') ??
                  'Share location as PDF',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              final String dynamicLink = await _createDynamicLink(
                widget.countryId,
                widget.cityId,
                widget.locationId,
              );
              final output = await getTemporaryDirectory();
              final file = File("${output.path}/location.pdf");
              final pdf = pw.Document();

              Uint8List? locationImageBytes;
              if (_locationImageUrl.isNotEmpty &&
                  _locationImageUrl.startsWith('http')) {
                locationImageBytes = await _downloadImage(_locationImageUrl);
              }
              final qrCodeImage = await _generateQRCodeImage(dynamicLink);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(32),
                  build: (pw.Context context) {
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Conexa Life',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal700,
                          ),
                        ),
                        pw.Divider(color: PdfColors.teal700),
                        pw.SizedBox(height: 16),
                        pw.Text(
                          localizationService.translate('locationName') ??
                              'Location Name:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          _locationName,
                          style: pw.TextStyle(fontSize: 16),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          localizationService.translate('address') ??
                              'Address:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          _locationAddress,
                          style: pw.TextStyle(fontSize: 16),
                        ),
                        pw.SizedBox(height: 16),
                        if (locationImageBytes != null &&
                            locationImageBytes.isNotEmpty)
                          pw.Container(
                            height: 200,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(locationImageBytes),
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        if (locationImageBytes != null &&
                            locationImageBytes.isNotEmpty)
                          pw.SizedBox(height: 16),
                        pw.Center(
                          child: pw.Column(
                            children: [
                              pw.Image(
                                pw.MemoryImage(qrCodeImage),
                                height: 300,
                                width: 300,
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(
                                localizationService.translate('scanQRCode') ??
                                    'Scan QR code to join location',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 24),
                        pw.Text(
                          localizationService.translate('communityMessage') ??
                              'Your community...',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Spacer(),
                        pw.Center(
                          child: pw.Text(
                            'conexa.life',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
              await file.writeAsBytes(await pdf.save());
              Share.shareXFiles(
                [XFile(file.path)],
                text:
                    localizationService.translate('shareLocationPDFSubject') ??
                        'Check out location $_locationName',
              );
            },
          ),
          Card(
            margin: const EdgeInsets.only(top: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_locationImageUrl.isNotEmpty) _buildLocationImage(),
                  const SizedBox(height: 10),
                  Text(
                    '${localizationService.translate('locationName') ?? 'Location Name'}: $_locationName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${localizationService.translate('address') ?? 'Address'}: $_locationAddress',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dynamicLink.isNotEmpty
                              ? _dynamicLink
                              : (localizationService
                                      .translate('linkGenerating') ??
                                  'Generating link...'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _dynamicLink.isNotEmpty
                            ? () {
                                Clipboard.setData(
                                  ClipboardData(text: _dynamicLink),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      localizationService
                                              .translate('linkCopied') ??
                                          'Link copied!',
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _isGeneratingLink
                      ? const Center(child: CircularProgressIndicator())
                      : _dynamicLink.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  localizationService
                                          .translate('locationQRCode') ??
                                      'Location QR Code',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                QrImageView(
                                  data: _dynamicLink,
                                  version: QrVersions.auto,
                                  size: 200.0,
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: () {
                                    _shareLocationLink(
                                      context,
                                      widget.countryId,
                                      widget.cityId,
                                      widget.locationId,
                                    );
                                  },
                                  icon: const Icon(Icons.share),
                                  label: Text(
                                    localizationService
                                            .translate('shareQRCode') ??
                                        'Share QR Code',
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              localizationService
                                      .translate('qrCodeUnavailable') ??
                                  'QR code unavailable.',
                              style: const TextStyle(color: Colors.red),
                            ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            localizationService.translate('administrators') ??
                'Administrators:',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          _isLoadingAdmins
              ? const Center(child: CircularProgressIndicator())
              : _administrators.isNotEmpty
                  ? Column(
                      children: _administrators.map((admin) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: admin
                                        .profileImageUrl.isNotEmpty
                                    ? (admin.profileImageUrl.startsWith('http')
                                        ? NetworkImage(admin.profileImageUrl)
                                        : AssetImage(admin.profileImageUrl)
                                            as ImageProvider)
                                    : const AssetImage(
                                        'assets/images/default_user.png'),
                                onBackgroundImageError: (_, __) {
                                  setState(() {
                                    admin.profileImageUrl =
                                        'assets/images/default_user.png';
                                  });
                                },
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${admin.displayName} ${admin.lastName}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (_isLocationAdmin)
                                          Row(
                                            children: [
                                              if (admin.phoneVisible)
                                                Text(
                                                  '(${admin.phone})',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  admin.phoneVisible
                                                      ? Icons.visibility
                                                      : Icons.visibility_off,
                                                  size: 20,
                                                  color: Colors.grey[600],
                                                ),
                                                onPressed: () {
                                                  _toggleAdminPhoneVisibility(
                                                      admin.userId,
                                                      admin.phoneVisible);
                                                },
                                              ),
                                            ],
                                          )
                                        else if (admin.phoneVisible)
                                          Text(
                                            '(${admin.phone})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Text(
                      localizationService.translate('noAdministrators') ??
                          'No administrators for this location.',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
        ],
      ),
    );
  }
}

class Admin {
  final String userId;
  final String displayName;
  final String lastName;
  final String phone;
  String profileImageUrl;
  final bool phoneVisible;

  Admin({
    required this.userId,
    required this.displayName,
    required this.lastName,
    required this.phone,
    required this.profileImageUrl,
    required this.phoneVisible,
  });

  factory Admin.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Admin(
      userId: data['userId'] ?? '',
      displayName: data['displayName'] ?? '',
      lastName: data['lastName'] ?? '',
      phone: data['phone'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      phoneVisible: data['phoneVisible'] ?? true,
    );
  }
}
