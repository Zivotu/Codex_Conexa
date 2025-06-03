import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

import '../models/repair_request.dart';
import '../models/time_frame.dart';
import '../services/localization_service.dart';
import '../utils/activity_codes.dart';
import 'my_repair_request_details.dart';
import 'infos/info_services.dart';

class ReportIssueScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const ReportIssueScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  ReportIssueScreenState createState() => ReportIssueScreenState();
}

class ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  late LocalizationService localizationService;
  String? userAddress;
  String? fcmToken;

  List<Map<String, dynamic>> activeRepairRequests = [];
  List<Map<String, dynamic>> completedRepairs = [];

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  final List<String> _imagePaths = [];
  String? _videoPath;
  String? _selectedIssueType;
  final List<String> _selectedTimeSlots = [];

  Map<String, String> get _timeSlotsLocalized => {
        'radni_dani': localizationService.translate('radni_dani') ??
            'Radni dani (ponedjeljak - petak)',
        'vikendi': localizationService.translate('vikendi') ??
            'Vikendi (subota, nedjelja i praznici)',
        'jutro':
            localizationService.translate('jutro') ?? 'Jutro (6:00 - 12:00)',
        'popodne': localizationService.translate('popodne') ??
            'Popodne (12:00 - 18:00)',
        'večer':
            localizationService.translate('večer') ?? 'Večer (18:00 - 23:00)',
      };

  bool _isUploading = false;
  final ValueNotifier<double> _uploadProgressNotifier = ValueNotifier(0.0);

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _naseljeController = TextEditingController();

  final bool _isSubmitting = false;
  int? _durationDays;

  String? _selectedCityInternal;
  String? _selectedCountryInternal;
  String? _selectedCountryCodeInternal;

  @override
  void initState() {
    super.initState();
    localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    _fetchRepairRequests();
    _fetchUserAddress();
    _updateFCMToken();
    _showOnboardingScreen(context);

    if (widget.cityId.isNotEmpty) {
      _cityController.text = widget.cityId;
      _selectedCityInternal = widget.cityId;
    }

    _countryController.text = widget.countryId;

    if (widget.countryId.isEmpty ||
        widget.cityId.isEmpty ||
        widget.countryId == 'Unknown' ||
        widget.cityId == 'Unknown') {
      _fetchGeoLocationData();
    }
  }

  Future<void> _showOnboardingScreen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool shouldShow = prefs.getBool('show_services_onboarding') ?? true;
    if (shouldShow) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InfoServicesScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _uploadProgressNotifier.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _naseljeController.dispose();
    _addressController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _updateFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        setState(() {
          fcmToken = token;
        });
        debugPrint("FCM Token updated: $token");
      }
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }

  Future<void> _fetchUserAddress() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          userAddress = userData['address'];
          fcmToken = userData['fcmToken'];

          if (_addressController.text.isEmpty) {
            _addressController.text = userData['address'] ?? '';
          }
          if (_countryController.text.isEmpty ||
              _countryController.text == 'Unknown') {
            _countryController.text = userData['geoCountryId'] ?? '';
          }
          if (_cityController.text.isEmpty ||
              _cityController.text == 'Unknown') {
            _cityController.text = userData['geoCityId'] ?? '';
          }
        });
        debugPrint("User address fetched: $userAddress");
      }
    } catch (e) {
      debugPrint("Error fetching user address and FCM token: $e");
      setState(() {
        userAddress = localizationService.translate('errorLoadingAddress') ??
            'Greška pri učitavanju adrese';
        fcmToken = null;
      });
    }
  }

  Future<void> _fetchGeoLocationData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          if (_countryController.text.isEmpty ||
              _countryController.text == 'Unknown') {
            _countryController.text = userData['geoCountryId'] ?? '';
          }
          if (_cityController.text.isEmpty ||
              _cityController.text == 'Unknown') {
            _cityController.text = userData['geoCityId'] ?? '';
          }
        });

        debugPrint("Geo location data fetched from user document: "
            "Country - ${userData['geoCountryId']}, City - ${userData['geoCityId']}");

        if ((_countryController.text.isEmpty ||
                _countryController.text == 'Unknown') &&
            (_cityController.text.isEmpty ||
                _cityController.text == 'Unknown')) {
          await _getCurrentLocation();
        }
      }
    } catch (e) {
      debugPrint("Error fetching geo location data from user document: $e");
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('locationServicesDisabled') ??
                  'Usluge lokacije su onemogućene.',
            ),
          ),
        );
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizationService.translate('locationPermissionDenied') ??
                    'Dozvola za lokaciju je odbijena.',
              ),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService
                      .translate('locationPermissionDeniedForever') ??
                  'Dozvola za lokaciju je trajno odbijena.',
            ),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        setState(() {
          _countryController.text = placemark.country ?? '';
          _cityController.text = placemark.locality ?? '';
        });
        debugPrint("Geo location fetched using geolocator: "
            "Country - ${placemark.country}, City - ${placemark.locality}");
      } else {
        debugPrint("No placemarks found during reverse geocoding.");
      }
    } catch (e) {
      debugPrint("Error fetching current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('errorFetchingLocation') ??
                'Greška pri dohvaćanju lokacije.',
          ),
        ),
      );
    }
  }

  Future<void> _fetchRepairRequests() async {
    try {
      final usedCountryId = _countryController.text.isNotEmpty
          ? _countryController.text
          : widget.countryId;

      final repairRequestCollection = FirebaseFirestore.instance
          .collection('countries')
          .doc(usedCountryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('repair_requests')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid);

      final activeQuerySnapshot = await repairRequestCollection
          .where('status', whereIn: [
            'Published',
            'In Negotiation',
            'Job Agreed',
            'waitingforconfirmation',
            'Published_2',
          ])
          .orderBy('requestedDate', descending: true)
          .get();

      debugPrint(
          'Active Repair Requests Count: ${activeQuerySnapshot.docs.length}');
      final activeRepairs =
          activeQuerySnapshot.docs.map((doc) => doc.data()).toList();

      final completedQuerySnapshot = await repairRequestCollection
          .where('status', isEqualTo: 'completed')
          .orderBy('requestedDate', descending: true)
          .get();

      debugPrint(
          'Completed Repairs Count: ${completedQuerySnapshot.docs.length}');
      final completedRepairsList =
          completedQuerySnapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        activeRepairRequests = activeRepairs;
        completedRepairs = completedRepairsList;
      });
    } catch (error) {
      debugPrint("Error fetching repair requests: $error");
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizationService.translate('sendingRequest') ??
              'Slanje zahtjeva'),
          content: ValueListenableBuilder<double>(
            valueListenable: _uploadProgressNotifier,
            builder: (context, value, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 20),
                  Text(
                    '${(value * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submitRepairRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedIssueType == null || _selectedTimeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('pleaseFillAllFields') ??
                'Molimo popunite sva polja',
          ),
        ),
      );
      return;
    }

    if (_durationDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('pleaseSelectDuration') ??
                'Molimo odaberite trajanje oglasa',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgressNotifier.value = 0.0;
    });
    _showLoadingDialog();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final usedCountryId = _countryController.text.trim();
      final usedCityId = _cityController.text.trim();
      final address = _addressController.text.trim();
      final naselje = _naseljeController.text.trim();

      String reportNumber = generateUniqueReportNumber(user.uid, usedCityId);

      int totalFiles =
          _selectedImages.length + (_selectedVideo != null ? 1 : 0);
      if (totalFiles == 0) totalFiles = 1;

      for (var image in _selectedImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('repair_images')
            .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          uploadTask = ref.putData(bytes);
        } else {
          uploadTask = ref.putFile(File(image.path));
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress =
              snapshot.bytesTransferred / snapshot.totalBytes.toDouble();
          _uploadProgressNotifier.value += progress / totalFiles;
          if (_uploadProgressNotifier.value > 1.0) {
            _uploadProgressNotifier.value = 1.0;
          }
        });

        await uploadTask;
        final downloadUrl = await ref.getDownloadURL();
        _imagePaths.add(downloadUrl);
        debugPrint("Image uploaded: $downloadUrl");
      }

      if (_selectedVideo != null) {
        final ref = FirebaseStorage.instance.ref().child('repair_videos').child(
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedVideo!.name}');

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await _selectedVideo!.readAsBytes();
          uploadTask = ref.putData(bytes);
        } else {
          uploadTask = ref.putFile(File(_selectedVideo!.path));
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress =
              snapshot.bytesTransferred / snapshot.totalBytes.toDouble();
          _uploadProgressNotifier.value += progress / totalFiles;
          if (_uploadProgressNotifier.value > 1.0) {
            _uploadProgressNotifier.value = 1.0;
          }
        });

        await uploadTask;
        _videoPath = await ref.getDownloadURL();
        debugPrint("Video uploaded: $_videoPath");
      }

      final timeFrames = _selectedTimeSlots.map((slot) {
        switch (slot) {
          case 'jutro':
            return TimeFrame(
              label: localizationService.translate('jutro') ??
                  'Jutro (6:00 - 12:00)',
              startHour: 6,
              endHour: 12,
            );
          case 'popodne':
            return TimeFrame(
              label: localizationService.translate('popodne') ??
                  'Popodne (12:00 - 18:00)',
              startHour: 12,
              endHour: 18,
            );
          case 'večer':
            return TimeFrame(
              label: localizationService.translate('večer') ??
                  'Večer (18:00 - 23:00)',
              startHour: 18,
              endHour: 23,
            );
          case 'radni_dani':
            return TimeFrame(
              label: localizationService.translate('radni_dani') ??
                  'Radni dani (ponedjeljak - petak)',
              startHour: 8,
              endHour: 18,
            );
          case 'vikendi':
            return TimeFrame(
              label: localizationService.translate('vikendi') ??
                  'Vikendi (subota, nedjelja i praznici)',
              startHour: 8,
              endHour: 18,
            );
          default:
            return TimeFrame(
              label: slot,
              startHour: 0,
              endHour: 0,
            );
        }
      }).toList();

      final requestedDate = DateTime.now();
      final expirationDate = requestedDate.add(Duration(days: _durationDays!));

      final repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(usedCountryId)
          .collection('cities')
          .doc(usedCityId)
          .collection('repair_requests')
          .doc();

      final repairRequestId = repairRequestRef.id;

      final repairRequest = RepairRequest(
        id: repairRequestId,
        reportNumber: reportNumber,
        issueType: _selectedIssueType!,
        requestedDate: requestedDate,
        expirationDate: expirationDate,
        description: _descriptionController.text,
        notes: '',
        imagePaths: _imagePaths,
        videoPath: _videoPath,
        userId: user.uid,
        status: 'Published',
        durationDays: _durationDays!,
        timeFrames: timeFrames,
        offeredTimeSlots: [],
        selectedTimeSlot: null,
        servicerConfirmedTimeSlot: null,
        fcmToken: fcmToken,
        countryId: usedCountryId,
        cityId: usedCityId,
        locationId: widget.locationId,
        address: address,
        naselje: naselje,
        notificationSeen: false,
      );

      debugPrint("Repair Request Prepared: ${repairRequest.toMap()}");

      await repairRequestRef.set(repairRequest.toMap());

      debugPrint("Repair Request Saved with ID: $repairRequestId");

      if (!mounted) return;
      Navigator.of(context).pop(); // zatvaramo dijalog

      _resetForm();
      await _fetchRepairRequests();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('repairRequestSent') ??
              'Zahtjev za popravak je poslan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error submitting repair request: $e");
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorSubmittingRequest') ?? 'Greška pri slanju zahtjeva'}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  String generateUniqueReportNumber(String userId, String cityId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(1000000).toString().padLeft(6, '0');
    final input = userId + timestamp + cityId + random;
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 6).toUpperCase();
  }

  void _resetForm() {
    setState(() {
      _selectedIssueType = null;
      _descriptionController.clear();
      _selectedImages.clear();
      _selectedVideo = null;
      _imagePaths.clear();
      _videoPath = null;
      _selectedTimeSlots.clear();
      _uploadProgressNotifier.value = 0.0;
      _durationDays = null;
      _naseljeController.clear();
    });
  }

  Future<void> _pickImages() async {
    final pickedImages = await _picker.pickMultiImage();
    if (pickedImages.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedImages);
      });
      debugPrint("Images selected: ${pickedImages.length}");
    }
  }

  Future<void> _pickVideo() async {
    final pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedVideo != null) {
      setState(() {
        _selectedVideo = pickedVideo;
      });
      debugPrint("Video selected: ${pickedVideo.name}");
    }
  }

  Widget _buildThumbnailGrid() {
    List<Widget> thumbnails = [];

    thumbnails.addAll(_selectedImages.map((image) {
      return Stack(
        children: [
          kIsWeb
              ? Image.network(
                  image.path,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(image.path),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedImages.remove(image);
                });
              },
            ),
          ),
        ],
      );
    }).toList());

    if (_selectedVideo != null) {
      thumbnails.add(Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            color: Colors.black54,
            child: const Center(
              child:
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _selectedVideo = null;
                });
              },
            ),
          ),
        ],
      ));
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: thumbnails,
    );
  }

  Widget _buildActiveRepairRequests() {
    if (activeRepairRequests.isEmpty) {
      return Center(
        child: Text(
          localizationService.translate('noScheduledRepair') ??
              'Nema zakazanih popravaka',
          style: const TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }

    return Column(
      children: activeRepairRequests.map((repair) {
        String statusMessage = '';
        IconData statusIcon = Icons.info;
        Color iconColor = const Color.fromARGB(255, 160, 72, 13);

        final selectedTimeSlot = repair['selectedTimeSlot'];
        final servicerConfirmedTimeSlot = repair['servicerConfirmedTimeSlot'];
        final servicerOffers = repair['servicerOffers'] ?? [];

        if (repair['status'] == 'waitingforconfirmation') {
          statusMessage =
              localizationService.translate('waitingforconfirmation') ??
                  'Čekamo potvrdu termina.';
          statusIcon = Icons.hourglass_empty;
          iconColor = Colors.orangeAccent;
        } else if (repair['status'] == 'Published_2') {
          statusMessage =
              localizationService.translate('chooseServicerArrivalTime') ??
                  'Odaberite termin dolaska servisera.';
          statusIcon = Icons.schedule;
          iconColor = Colors.orange;
        } else if (servicerOffers.isNotEmpty && selectedTimeSlot == null) {
          statusMessage = localizationService.translate('selectTimeSlot') ??
              'Odaberite termin.';
          statusIcon = Icons.schedule;
          iconColor = Colors.orange;
        } else if (selectedTimeSlot != null &&
            servicerConfirmedTimeSlot == null) {
          statusMessage =
              localizationService.translate('waitingforconfirmation') ??
                  'Čekamo potvrdu servisera.';
          statusIcon = Icons.hourglass_empty;
          iconColor = Colors.orangeAccent;
        } else if (servicerConfirmedTimeSlot != null) {
          statusMessage = localizationService.translate('serviceConfirmed') ??
              'Servis je dogovoren!';
          statusIcon = Icons.check_circle;
          iconColor = Colors.green;
        } else if (servicerOffers.isEmpty) {
          statusMessage =
              localizationService.translate('searchingForServicer') ??
                  'Tražimo servisera!';
          statusIcon = Icons.search;
          iconColor = Colors.blue;
        }

        final bool showExtraInfo = servicerOffers.isEmpty;
        final String description = repair['description'] ?? '';
        final String descriptionExcerpt = description.length > 50
            ? '${description.substring(0, 50)}...'
            : description;
        final List<dynamic> imagePaths = repair['imagePaths'] ?? [];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          color: Colors.grey[100],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyRepairRequestDetails(
                    repairRequestId: repair['id'],
                    onCancelled: _fetchRepairRequests,
                    repairRequest: RepairRequest.fromMap(repair),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(statusIcon, color: iconColor, size: 40),
                    title: Text(
                      statusMessage,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: selectedTimeSlot != null
                        ? Text(
                            '${localizationService.translate('selectedTimeSlot') ?? 'Odabrani termin'}: ${_formatTimestamp(selectedTimeSlot)}',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.blue),
                          )
                        : null,
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.blue),
                  ),
                  if (showExtraInfo) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      descriptionExcerpt,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8.0),
                    if (imagePaths.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Image.network(
                                imagePaths[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompletedRepairsHistory() {
    if (completedRepairs.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.history, color: Colors.grey),
        title: Text(
          localizationService.translate('noCompletedRepairs') ??
              'Nema dovršenih popravaka',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: completedRepairs.map((repair) {
        final Timestamp? ts =
            repair['completedDate'] ?? repair['requestedDate'];
        final DateTime? displayDate = ts?.toDate();

        return ListTile(
          leading: const Icon(Icons.history, color: Colors.green),
          title: Text(
            localizationService.translate('completedRepair') ??
                'Završeni popravak',
          ),
          subtitle: Text(
            displayDate != null
                ? _formatDateTime(displayDate)
                : localizationService.translate('unknownCompletionDate') ??
                    'Nepoznat datum dovršetka',
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyRepairRequestDetails(
                  repairRequestId: repair['id'],
                  onCancelled: _fetchRepairRequests,
                  repairRequest: RepairRequest.fromMap(repair),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${_dayOfWeek(dateTime.weekday)} - ${_formatTime(dateTime)}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${_dayOfWeek(dateTime.weekday)} - ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return localizationService.translate('monday') ?? 'Ponedjeljak';
      case DateTime.tuesday:
        return localizationService.translate('tuesday') ?? 'Utorak';
      case DateTime.wednesday:
        return localizationService.translate('wednesday') ?? 'Srijeda';
      case DateTime.thursday:
        return localizationService.translate('thursday') ?? 'Četvrtak';
      case DateTime.friday:
        return localizationService.translate('friday') ?? 'Petak';
      case DateTime.saturday:
        return localizationService.translate('saturday') ?? 'Subota';
      case DateTime.sunday:
        return localizationService.translate('sunday') ?? 'Nedjelja';
      default:
        return '';
    }
  }

  Widget _buildTimeSlotOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _timeSlotsLocalized.entries.map((entry) {
        return CheckboxListTile(
          title: Text(
            entry.value,
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          value: _selectedTimeSlots.contains(entry.key),
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedTimeSlots.add(entry.key);
              } else {
                _selectedTimeSlots.remove(entry.key);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDurationDropdown() {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText:
            localizationService.translate('duration') ?? 'Trajanje oglasa',
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: 1,
          child: Text(localizationService.translate('1_day') ?? '1 dan'),
        ),
        DropdownMenuItem(
          value: 5,
          child: Text(localizationService.translate('5_days') ?? '5 dana'),
        ),
        DropdownMenuItem(
          value: 15,
          child: Text(localizationService.translate('15_days') ?? '15 dana'),
        ),
      ],
      onChanged: (int? value) {
        setState(() {
          _durationDays = value;
        });
      },
      value: _durationDays,
      validator: (value) {
        if (value == null) {
          return localizationService.translate('pleaseSelectDuration') ??
              'Molimo odaberite trajanje oglasa';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('reportIssue') ?? 'Prijavi problem',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informativni karton
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red, width: 1.5),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 30),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      localizationService.translate('serviceLimitedToZagreb') ??
                          'Usluga je trenutno dostupna samo za Zagreb',
                      style: TextStyle(color: Colors.red[900], fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            _buildActiveRepairRequests(),
            const SizedBox(height: 16.0),

            Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: _isUploading,
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizationService.translate('reportTitle') ?? 'Prijava problema'} #${generateUniqueReportNumber(FirebaseAuth.instance.currentUser!.uid, _cityController.text)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '${localizationService.translate('userName') ?? 'Korisnik'}: ${widget.username}',
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _cityController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText:
                                localizationService.translate('city') ?? 'Grad',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizationService
                                      .translate('pleaseFillAllFields') ??
                                  'Molimo popunite sva polja';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _naseljeController,
                          decoration: InputDecoration(
                            labelText:
                                localizationService.translate('naselje') ??
                                    'Naselje',
                            border: const OutlineInputBorder(),
                            hintText:
                                localizationService.translate('enterNaselje') ??
                                    'Unesite ime naselja',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizationService
                                      .translate('enterNaselje') ??
                                  'Molimo unesite naselje.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: localizationService
                                    .translate('interventionAddress') ??
                                'Adresa intervencije',
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizationService
                                      .translate('pleaseFillAllFields') ??
                                  'Molimo popunite sva polja';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        _buildDurationDropdown(),
                        const SizedBox(height: 16.0),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText:
                                localizationService.translate('issueType') ??
                                    'Tip problema',
                            border: const OutlineInputBorder(),
                          ),
                          items: ActivityCodes.getAllCategories(
                                  localizationService)
                              .map((category) {
                            return DropdownMenuItem<String>(
                              value: category['type'],
                              child: Text(category['name']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedIssueType = value;
                            });
                          },
                          value: _selectedIssueType,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizationService
                                      .translate('pleaseFillAllFields') ??
                                  'Molimo popunite sva polja';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: localizationService
                                    .translate('problemDescription') ??
                                'Opis problema',
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizationService
                                      .translate('pleaseFillAllFields') ??
                                  'Molimo popunite sva polja';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          localizationService.translate('chooseTimeSlots') ??
                              'Odaberite vrijeme',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8.0),
                        _buildTimeSlotOptions(),
                        const SizedBox(height: 16.0),
                        _buildThumbnailGrid(),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _pickImages,
                                icon: const Icon(Icons.image),
                                label: Text(
                                  localizationService
                                          .translate('selectImages') ??
                                      'Odaberi slike',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _pickVideo,
                                icon: const Icon(Icons.videocam),
                                label: Text(
                                  localizationService
                                          .translate('selectVideo') ??
                                      'Odaberi video',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        if (_isUploading)
                          LinearProgressIndicator(
                            value: _uploadProgressNotifier.value,
                          ),
                        const SizedBox(height: 16.0),
                        Center(
                          child: ElevatedButton(
                            onPressed:
                                _isUploading ? null : _submitRepairRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: Text(
                              localizationService.translate('submitRequest') ??
                                  'Pošalji zahtjev',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16.0),

            Text(
              localizationService.translate('repairHistory') ??
                  'Historija popravaka',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _buildCompletedRepairsHistory(),
          ],
        ),
      ),
    );
  }
}
