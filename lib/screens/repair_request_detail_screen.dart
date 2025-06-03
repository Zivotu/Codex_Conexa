// lib/screens/repair_request_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/repair_request.dart' as models;
import '../services/localization_service.dart';
import 'send_offer_screen.dart';
import '../widgets/status_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart'; // Dodano za QR kodove
import 'package:share_plus/share_plus.dart'; // Dodano za dijeljenje

class RepairRequestDetailScreen extends StatefulWidget {
  final models.RepairRequest repairRequest;

  const RepairRequestDetailScreen({
    super.key,
    required this.repairRequest,
  });

  @override
  State<RepairRequestDetailScreen> createState() =>
      _RepairRequestDetailScreenState();
}

class _RepairRequestDetailScreenState extends State<RepairRequestDetailScreen> {
  VideoPlayerController? _videoController;
  String? userFullName;
  String? userAddress;
  String? userPhone;
  bool showPhoneNumber = false;
  bool isArrivalConfirmed = false;
  bool _isFullScreenImage = false;
  int? _selectedImageIndex;
  String? _servicerId;
  String? _servicerFcmToken;
  String? _userFcmToken;
  String? naselje;

  // Varijable za opis posla, cijenu, kod i QR kod
  final TextEditingController _workDescriptionController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _uniqueCode;
  String? _qrCodeData;
  bool _isEditing = false;

  // Status
  String _status = 'Published';

  // Localization
  late LocalizationService localizationService;

  // Notifier za napredak upload-a
  final ValueNotifier<double> _uploadProgressNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    isArrivalConfirmed = widget.repairRequest.servicerConfirmedTimeSlot != null;
    _initializeDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizationService = Provider.of<LocalizationService>(context);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _workDescriptionController.dispose();
    _priceController.dispose();
    _uploadProgressNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeDetails() async {
    await _fetchServicerDetails();
    await _fetchUserDetails();
    _updatePhoneVisibility();

    // Slušanje promjena u dokumentu zahtjeva za popravak
    FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.repairRequest.countryId)
        .collection('cities')
        .doc(widget.repairRequest.cityId)
        .collection('repair_requests')
        .doc(widget.repairRequest.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _status = snapshot.data()?['status'] ?? 'Published';
        });
      }
    });

    if (widget.repairRequest.videoPath != null &&
        widget.repairRequest.videoPath!.isNotEmpty) {
      _videoController =
          VideoPlayerController.network(widget.repairRequest.videoPath!)
            ..initialize().then((_) {
              setState(() {});
            });
    }

    // Ako posao već postoji, dohvatite ga
    await _fetchJobDetails();
  }

  Future<void> _fetchJobDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final servicerId = currentUser.uid;

    try {
      final jobDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(servicerId)
          .collection('jobs')
          .where('repairRequestId', isEqualTo: widget.repairRequest.id)
          .limit(1)
          .get();

      if (jobDoc.docs.isNotEmpty) {
        final jobData = jobDoc.docs.first.data();
        setState(() {
          _workDescriptionController.text = jobData['workDescription'] ?? '';
          _priceController.text =
              jobData['price'] != null ? jobData['price'].toString() : '';
          _uniqueCode = jobData['uniqueCode'];
          _qrCodeData = jobData['qrCodeData'];

          if (_workDescriptionController.text.isNotEmpty &&
              _priceController.text.isNotEmpty) {
            _isEditing = false;
          } else {
            _isEditing = true;
          }
        });
      } else {
        setState(() {
          _isEditing = true;
        });
      }
    } catch (e) {
      print('Greška prilikom dohvaćanja detalja posla: $e');
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.repairRequest.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          final displayName = userDoc['displayName'] ?? 'Nepoznato ime';
          userFullName = '$displayName'.trim();
          userAddress = userDoc['address'] ?? 'N/A';
          userPhone = userDoc['phone'] ?? 'N/A';
          _userFcmToken = userDoc['fcmToken'] ?? '';
        });
      }
    } catch (e) {
      print('Greška prilikom dohvaćanja korisničkih podataka: $e');
    }
  }

  void _updatePhoneVisibility() {
    if (widget.repairRequest.selectedTimeSlot != null) {
      final DateTime scheduledTime =
          widget.repairRequest.selectedTimeSlot!.toDate();
      final now = DateTime.now();
      final threeHoursBefore = scheduledTime.subtract(const Duration(hours: 3));
      final oneHourAfter = scheduledTime.add(const Duration(hours: 1));

      setState(() {
        showPhoneNumber =
            now.isAfter(threeHoursBefore) && now.isBefore(oneHourAfter);
      });

      if (!showPhoneNumber) {
        Future.delayed(const Duration(minutes: 15), _updatePhoneVisibility);
      }
    }
  }

  Future<void> _fetchServicerDetails() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('Korisnik nije prijavljen.');
        return;
      }

      final servicerId = currentUser.uid;
      if (servicerId.isNotEmpty) {
        final servicerDoc = await FirebaseFirestore.instance
            .collection('servicers')
            .doc(servicerId)
            .get();

        if (servicerDoc.exists) {
          setState(() {
            _servicerId = servicerId;
            _servicerFcmToken = servicerDoc['fcmToken'] ??
                widget.repairRequest.servicerFcmToken;
          });
        } else {
          print('Servicer dokument nije pronađen.');
        }
      } else {
        print('Servicer ID je prazan.');
      }
    } catch (e) {
      print('Greška prilikom dohvaćanja detalja servisera: $e');
    }
  }

  // Generiranje jedinstvenog koda od 5 znakova
  String _generateUniqueCode(String description, double price, DateTime date) {
    final seed = description + price.toString() + date.toIso8601String();
    final rand = Random(seed.hashCode);
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(5, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> _saveJob() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('userNotLoggedIn') ??
              'Korisnik nije prijavljen.'),
        ),
      );
      return;
    }

    String description = _workDescriptionController.text.trim();
    String priceText = _priceController.text.trim();

    if (description.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('fillAllFields') ??
              'Molimo popunite sva polja.'),
        ),
      );
      return;
    }

    double? price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('invalidPrice') ??
              'Nevažeća cijena.'),
        ),
      );
      return;
    }

    DateTime now = DateTime.now();
    String code = _generateUniqueCode(description, price, now);
    // Uklonjeno case-sensitivity -> Korisnik ne treba razlikovati velika i mala slova
    code = code.toUpperCase();

    String qrCodeData = code; // Prilagodite URL po potrebi

    try {
      final servicerId = currentUser.uid;
      final jobsRef = FirebaseFirestore.instance
          .collection('servicers')
          .doc(servicerId)
          .collection('jobs');

      // Provjera postoji li već posao za ovaj zahtjev
      final existingJob = await jobsRef
          .where('repairRequestId', isEqualTo: widget.repairRequest.id)
          .limit(1)
          .get();

      if (existingJob.docs.isNotEmpty) {
        // Ažuriranje postojećeg posla
        final jobDoc = existingJob.docs.first;
        await jobDoc.reference.update({
          'workDescription': description,
          'price': price,
          'uniqueCode': code,
          'qrCodeData': qrCodeData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Kreiranje novog posla
        await jobsRef.add({
          'repairRequestId': widget.repairRequest.id,
          'workDescription': description,
          'price': price,
          'uniqueCode': code,
          'qrCodeData': qrCodeData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reportNumber': widget.repairRequest.reportNumber,
          'issueType': widget.repairRequest.issueType,
          'requestedDate': widget.repairRequest.requestedDate,
          'description': widget.repairRequest.description,
          'status': widget.repairRequest.status,
          'userId': widget.repairRequest.userId,
        });
      }

      setState(() {
        _uniqueCode = code;
        _qrCodeData = qrCodeData;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('jobSaved') ??
              'Posao je uspješno spremljen.'),
        ),
      );
    } catch (e) {
      print('Greška prilikom spremanja posla: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${localizationService.translate('errorSavingJob') ?? 'Greška prilikom spremanja posla'}: $e'),
        ),
      );
    }
  }

  Future<void> _editJob() async {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _cancelJobEdit() async {
    await _fetchJobDetails();
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _confirmSelectedTimeSlot() async {
    if (_servicerFcmToken == null || _servicerFcmToken!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('servicerFcmTokenMissing') ??
                  'Servicer FCM token is missing.',
            ),
          ),
        );
      }
      return;
    }

    try {
      final repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.repairRequest.countryId)
          .collection('cities')
          .doc(widget.repairRequest.cityId)
          .collection('repair_requests')
          .doc(widget.repairRequest.id);

      await repairRequestRef.update({
        'servicerConfirmedTimeSlot': widget.repairRequest.selectedTimeSlot,
        'servicerFcmToken': _servicerFcmToken,
        'status': 'Job Agreed',
      });

      setState(() {
        isArrivalConfirmed = true;
        _status = 'Job Agreed'; // Update status
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  localizationService.translate('jobAgreed') ??
                      'Posao je dogovoren!',
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Greška prilikom potvrde termina: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('errorConfirmingTimeSlot') ??
                  'Došlo je do greške prilikom potvrde termina: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelInterventionWithReason() async {
    TextEditingController reasonController = TextEditingController();

    bool confirmCancel = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(localizationService.translate('cancelIntervention') ??
                  "Otkazivanje intervencije"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(localizationService
                          .translate('enterCancellationReason') ??
                      "Unesite razlog otkazivanja:"),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: localizationService
                              .translate('cancellationReasonHint') ??
                          "Razlog otkazivanja",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                      localizationService.translate('cancel') ?? "Odustani"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localizationService.translate('confirmCancel') ??
                      "Otkazati"),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmCancel) return;

    String reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                localizationService.translate('cancellationReasonRequired') ??
                    "Razlog otkazivanja je obavezan.")),
      );
      return;
    }

    DateTime now = DateTime.now();

    String? countryId = widget.repairRequest.countryId;
    String? cityId = widget.repairRequest.cityId;
    String? repairRequestId = widget.repairRequest.id;

    DocumentReference repairRequestRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('repair_requests')
        .doc(repairRequestId);

    CollectionReference cancelledRequestsRef =
        repairRequestRef.collection('cancelled_requests');

    try {
      String? servicerId = _servicerId;
      String servicerFirstName = 'Serviser';
      String servicerLastName = '';
      String? servicerFcmToken = _servicerFcmToken;

      if (servicerId != null && servicerId.isNotEmpty) {
        DocumentSnapshot servicerSnapshot = await FirebaseFirestore.instance
            .collection('servicers')
            .doc(servicerId)
            .get();

        if (servicerSnapshot.exists) {
          servicerFirstName =
              servicerSnapshot['firstName'] as String? ?? 'Serviser';
          servicerLastName = servicerSnapshot['lastName'] as String? ?? '';
          servicerFcmToken = servicerSnapshot['fcmToken'] as String?;
        } else {
          print('Servicer dokument ne postoji za servicerId: $servicerId');
        }
      }

      String servicerName = '$servicerFirstName $servicerLastName'.trim();

      String? userId = widget.repairRequest.userId;
      String? userFcmToken = _userFcmToken;

      DocumentReference newCancelDoc = await cancelledRequestsRef.add({
        'userId': widget.repairRequest.userId,
        'servicerId': servicerId ?? '',
        'requestId': repairRequestId,
        'userName': userFullName ?? 'Korisnik',
        'cancelledAt': Timestamp.fromDate(now),
        'reason': reason,
        'canceledBy': 'servicer',
        'servicerName': servicerName.isNotEmpty ? servicerName : 'Serviser',
        'userFcmToken': userFcmToken ?? '',
        'servicerFcmToken': servicerFcmToken ?? '',
      });

      await repairRequestRef.update({
        'status': 'Cancelled',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                localizationService.translate('interventionCancelled') ??
                    'Zahtjev je uspješno otkazan.')),
      );

      Navigator.pop(context);
      print(
          'Zahtjev je otkazan i dokument kreiran u cancelled_requests: ${newCancelDoc.id}');
    } catch (e) {
      print('Greška prilikom otkazivanja: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              localizationService.translate('errorCancellingIntervention') ??
                  'Došlo je do greške: $e'),
        ),
      );
    }
  }

  Future<void> _cancelOffer() async {
    try {
      final repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.repairRequest.countryId)
          .collection('cities')
          .doc(widget.repairRequest.cityId)
          .collection('repair_requests')
          .doc(widget.repairRequest.id);

      await repairRequestRef.update({
        'servicerIds': FieldValue.arrayRemove([_servicerId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('offerCancelled') ??
              'Ponuda je otkazana.'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Greška prilikom otkazivanja ponude: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('errorCancellingOffer') ??
              'Došlo je do greške prilikom otkazivanja ponude: $e'),
        ),
      );
    }
  }

  String _formatFullDate(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}.';
  }

  String _formatDayAndTime(
      DateTime dateTime, LocalizationService localizationService) {
    return '${_dayOfWeek(dateTime.weekday, localizationService)} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

  String _dayOfWeek(int weekday, LocalizationService localizationService) {
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

  void _toggleFullScreenImage(int index) {
    setState(() {
      _selectedImageIndex = index;
      _isFullScreenImage = !_isFullScreenImage;
    });

    if (_isFullScreenImage && _selectedImageIndex != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: CachedNetworkImage(
              imageUrl: widget.repairRequest.imagePaths
                      .elementAt(_selectedImageIndex!) ??
                  '',
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 100, color: Colors.grey),
            ),
          ),
        ),
      ).then((_) {
        setState(() {
          _isFullScreenImage = false;
          _selectedImageIndex = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = this.localizationService;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('details') ?? 'Detalji',
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('countries')
            .doc(widget.repairRequest.countryId)
            .collection('cities')
            .doc(widget.repairRequest.cityId)
            .collection('repair_requests')
            .doc(widget.repairRequest.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final repairRequestData =
              snapshot.data!.data() as Map<String, dynamic>;
          final status = repairRequestData['status'] ?? 'Published';
          final servicerConfirmedTimeSlot =
              repairRequestData['servicerConfirmedTimeSlot'];
          final selectedTimeSlot = repairRequestData['selectedTimeSlot'];
          final timeFrames = repairRequestData['timeFrames'] as List<dynamic>?;
          naselje = repairRequestData['naselje'] as String?;

          final servicerIds =
              List<String>.from(repairRequestData['servicerIds'] ?? []);
          bool hasSentOffer =
              _servicerId != null && servicerIds.contains(_servicerId!);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _status = status;
            });
          });

          String statusMessage = '';
          if (status == 'completed' || status == 'Closed') {
            statusMessage = localizationService.translate('jobCompleted') ??
                'Posao je završen!';
          } else if (status == 'Published' && !hasSentOffer) {
            statusMessage =
                localizationService.translate('checkDesiredArrivalPeriods') ??
                    'Provjerite željene periode dolaska korisnika.';
          } else if (hasSentOffer) {
            if (selectedTimeSlot == null) {
              statusMessage =
                  localizationService.translate('userConsideringOffer') ??
                      'Korisnik razmatra vašu ponudu...';
            } else if (selectedTimeSlot != null &&
                servicerConfirmedTimeSlot == null) {
              DateTime selectedDate = (selectedTimeSlot as Timestamp).toDate();
              String formattedDate =
                  '${_formatFullDate(selectedDate)} ${_formatDayAndTime(selectedDate, localizationService)}';
              statusMessage =
                  '${localizationService.translate('confirmArrival') ?? 'Potvrdite dolazak!'}\n$formattedDate';
            } else if (servicerConfirmedTimeSlot != null) {
              DateTime confirmedTime =
                  (servicerConfirmedTimeSlot as Timestamp).toDate();
              String formattedDate =
                  '${_formatFullDate(confirmedTime)} ${_formatDayAndTime(confirmedTime, localizationService)}';
              statusMessage =
                  '${localizationService.translate('scheduledIntervention') ?? 'Zakazano vrijeme intervencije'} $formattedDate';
            }
          } else if (status == 'Job Agreed' &&
              servicerConfirmedTimeSlot != null) {
            DateTime confirmedTime =
                (servicerConfirmedTimeSlot as Timestamp).toDate();
            String formattedDate =
                '${_formatFullDate(confirmedTime)} ${_formatDayAndTime(confirmedTime, localizationService)}';
            statusMessage =
                '${localizationService.translate('scheduledIntervention') ?? 'Zakazano vrijeme intervencije'} $formattedDate';
          } else {
            statusMessage = localizationService.translate('unknownStatus') ??
                'Nepoznati status';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatFullDate(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                StatusWidget(
                  status: status,
                  localizationService: localizationService,
                  customMessage: statusMessage,
                ),
                const SizedBox(height: 16.0),
                if (status == 'Job Agreed' && servicerConfirmedTimeSlot != null)
                  Card(
                    color: Colors.green[50],
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizationService.translate('address') ??
                                'Adresa:',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.repairRequest.countryId}, ${widget.repairRequest.cityId}, ${naselje ?? ''}, ${widget.repairRequest.address ?? ''}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          if (userFullName != null && userFullName!.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizationService.translate('name') ??
                                      'Ime:',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  userFullName!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (showPhoneNumber && userPhone != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizationService.translate('phone') ??
                                      'Telefon:',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final phoneUri =
                                        Uri(scheme: 'tel', path: userPhone);
                                    launchUrl(phoneUri);
                                  },
                                  child: Text(
                                    userPhone!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (status == 'Published' && !hasSentOffer)
                  _buildDesiredTimeFrames(timeFrames, localizationService),
                if (hasSentOffer)
                  _buildServicerOffers(repairRequestData, localizationService),
                const SizedBox(height: 16.0),
                Text(
                  '${localizationService.translate('reportTitle') ?? 'Prijava'} #${widget.repairRequest.reportNumber ?? ''}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  '${localizationService.translate('description') ?? 'Opis'}: ${widget.repairRequest.description ?? ''}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16.0),
                _buildImagesAndVideo(),
                const SizedBox(height: 16.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatTimestamp(
                        Timestamp.fromDate(widget.repairRequest.requestedDate)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildJobForm(localizationService),
                const SizedBox(height: 20.0),
                _buildActionButtons(
                  localizationService,
                  status,
                  hasSentOffer,
                  selectedTimeSlot,
                  servicerConfirmedTimeSlot,
                ),
                if (_uniqueCode != null && _qrCodeData != null)
                  Align(
                    alignment: Alignment.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}.';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Widget to display images and video
  Widget _buildImagesAndVideo() {
    if (widget.repairRequest.imagePaths.isEmpty &&
        (widget.repairRequest.videoPath == null ||
            widget.repairRequest.videoPath!.isEmpty)) {
      return const SizedBox.shrink();
    }

    List<Widget> mediaWidgets = [];

    if (widget.repairRequest.imagePaths.isNotEmpty) {
      mediaWidgets.add(
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: widget.repairRequest.imagePaths.map((path) {
            int index = widget.repairRequest.imagePaths.indexOf(path);
            return GestureDetector(
              onTap: () {
                _toggleFullScreenImage(index);
              },
              child: CachedNetworkImage(
                imageUrl: path,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (widget.repairRequest.videoPath != null &&
        widget.repairRequest.videoPath!.isNotEmpty) {
      mediaWidgets.add(
        GestureDetector(
          onTap: () {
            if (_videoController != null &&
                _videoController!.value.isInitialized) {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ).then((_) {
                _videoController!.pause();
              });
              _videoController!.play();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black54,
                  height: 200,
                  width: double.infinity,
                  child: _videoController != null &&
                          _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const Icon(
                          Icons.videocam,
                          size: 100,
                          color: Colors.white70,
                        ),
                ),
              ),
              const Icon(
                Icons.play_circle_fill,
                size: 50,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mediaWidgets,
    );
  }

  // Widget za prikaz željenih vremenskih okvira
  Widget _buildDesiredTimeFrames(
      List<dynamic>? timeFrames, LocalizationService localizationService) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prikaz željenih vremenskih okvira korisnika
            Text(
              localizationService.translate('desiredArrivalPeriod') ??
                  'Željeni period dolaska',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: timeFrames != null && timeFrames.isNotEmpty
                  ? timeFrames.map((frame) {
                      final label = frame['label'] as String? ?? '';
                      final startHour = frame['startHour'] as int?;
                      final endHour = frame['endHour'] as int?;

                      String timeFrameText =
                          '$label: $startHour:00h - $endHour:00h';

                      return Text(
                        timeFrameText,
                        style: const TextStyle(fontSize: 16),
                      );
                    }).toList()
                  : [
                      Text(
                        localizationService.translate('noPreferredTimes') ??
                            'Nema postavljenih željenih termina.',
                        style: const TextStyle(fontSize: 16),
                      )
                    ],
            ),
            const SizedBox(height: 16),
            // Prikaz naselja
            if (naselje != null && naselje!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizationService.translate('naselje') ?? 'Naselje:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    naselje!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Prikaz imena korisnika
            if (userFullName != null && userFullName!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizationService.translate('name') ?? 'Ime:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userFullName!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // Prikaz datuma objave oglasa
            Row(
              children: [
                Text(
                  localizationService.translate('publicationDate') ??
                      'Datum objave:',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(
                      Timestamp.fromDate(widget.repairRequest.requestedDate)),
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
    );
  }

  // Widget za prikaz ponuda servisera
  Widget _buildServicerOffers(Map<String, dynamic> repairRequestData,
      LocalizationService localizationService) {
    final servicerOffers =
        repairRequestData['servicerOffers'] as List<dynamic>?;

    return servicerOffers != null && servicerOffers.isNotEmpty
        ? Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prikaz ponuđenih vremenskih okvira servisera
                  Text(
                    localizationService.translate('servicerOffers') ??
                        'Ponude servisera',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: servicerOffers.map((offer) {
                      final List<dynamic> offerTimeSlots =
                          offer['timeSlots'] ?? [];
                      final String servicerName =
                          offer['servicerName'] ?? 'Serviser';
                      final String servicerProfileImageUrl =
                          offer['servicerProfileImageUrl'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Informacije o serviseru
                            Row(
                              children: [
                                if (servicerProfileImageUrl.isNotEmpty)
                                  CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(servicerProfileImageUrl),
                                  )
                                else
                                  const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  servicerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Prikaz vremenskih okvira servisera
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: offerTimeSlots.map((slot) {
                                final Timestamp timestamp = slot as Timestamp;
                                final DateTime dateTime = timestamp.toDate();
                                return Text(
                                  _formatDayAndTime(
                                      dateTime, localizationService),
                                  style: const TextStyle(fontSize: 16),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  // Widget za prikaz obrasca za unos posla, cijenu i generiranje koda
  Widget _buildJobForm(LocalizationService localizationService) {
    final bool isJobEditable = _status != 'completed' && _status != 'Closed';
    final bool areFieldsEmpty = (_workDescriptionController.text.isEmpty &&
        _priceController.text.isEmpty);
    final bool isInitialEditable = areFieldsEmpty && isJobEditable;

    if (isInitialEditable && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isEditing = true;
        });
      });
    }

    return Card(
      color: Colors.orange[50],
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Naslov
            Text(
              localizationService.translate('jobDetails') ?? 'Detalji Posla',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16.0),

            // Opis posla
            TextField(
              controller: _workDescriptionController,
              decoration: InputDecoration(
                labelText: localizationService.translate('workDescription') ??
                    'Opis Posla',
                border: const OutlineInputBorder(),
              ),
              maxLines: null,
              enabled: _isEditing && isJobEditable,
            ),
            const SizedBox(height: 16.0),

            // Cijena
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: localizationService.translate('price') ?? 'Cijena',
                border: const OutlineInputBorder(),
                prefixText: '€ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              enabled: _isEditing && isJobEditable,
            ),
            const SizedBox(height: 16.0),

            // Generiranje koda
            ElevatedButton(
              onPressed: (_isEditing && isJobEditable)
                  ? () async {
                      await _saveJob(); // Sprema podatke i generira kod
                      setState(() {
                        _isEditing = false; // Zaključava polja nakon spremanja
                      });
                    }
                  : null, // Gumb je deaktiviran ako polja nisu aktivna za uređivanje
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                localizationService.translate('generateCode') ??
                    'Generiraj kod',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16.0),

            // Prikaz generiranog koda i gumb "Uredi"
            if (_uniqueCode != null && isJobEditable)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${localizationService.translate('uniqueCode') ?? 'Jedinstveni Kod'}: $_uniqueCode',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_status != 'completed' && _status != 'Closed')
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      child: Text(
                        localizationService.translate('edit') ?? 'Uredi',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            if (_qrCodeData != null && _qrCodeData!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizationService.translate('jobQRCode') ??
                        'QR Kod Posla',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: _qrCodeData!,
                    version: QrVersions.auto,
                    size: 150.0,
                    gapless: false,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _shareJobQRCode() {
    if (_qrCodeData == null || _qrCodeData!.isEmpty) return;
    Share.share(
      _qrCodeData!,
      subject: 'QR Kod Posla',
    );
  }

  // Widget za akcijske gumbe
  Widget _buildActionButtons(
      LocalizationService localizationService,
      String status,
      bool hasSentOffer,
      Timestamp? selectedTimeSlot,
      Timestamp? servicerConfirmedTimeSlot) {
    return Column(
      children: [
        if (status == 'Published' && !hasSentOffer)
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SendOfferScreen(
                      repairRequest: widget.repairRequest,
                      servicerId: FirebaseAuth.instance.currentUser!.uid,
                    ),
                  ),
                ).then((_) {
                  _fetchServicerDetails();
                });
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                backgroundColor: Colors.green,
              ),
              child: Text(
                localizationService.translate('sendOffer') ?? 'Pošalji ponudu',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        if (hasSentOffer && selectedTimeSlot == null)
          Center(
            child: ElevatedButton(
              onPressed: _cancelOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                localizationService.translate('cancelOffer') ?? 'Otkaži ponudu',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        if (hasSentOffer &&
            selectedTimeSlot != null &&
            servicerConfirmedTimeSlot == null)
          Center(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _confirmSelectedTimeSlot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    localizationService.translate('confirmArrival') ??
                        'Potvrdi dolazak',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _cancelInterventionWithReason,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    localizationService.translate('cancelIntervention') ??
                        'Otkaži intervenciju',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        if (status == 'Job Agreed' && servicerConfirmedTimeSlot != null)
          Center(
            child: ElevatedButton(
              onPressed: _cancelInterventionWithReason,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                localizationService.translate('cancelIntervention') ??
                    'Otkaži intervenciju',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
