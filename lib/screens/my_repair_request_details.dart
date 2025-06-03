// lib/screens/my_repair_request_details.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ovaj import zadržavamo ako QRScannerScreen dolazi iz drugog mjesta
import '../services/user_service.dart';

import '../screens/qr_scanner_screen.dart'; // ili točan path do tog fajla

import '../services/localization_service.dart';
import '../services/servicer_service.dart';
import '../models/repair_request.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

class MyRepairRequestDetails extends StatefulWidget {
  final String repairRequestId;
  final VoidCallback onCancelled;
  final RepairRequest? repairRequest;

  const MyRepairRequestDetails({
    super.key,
    required this.repairRequestId,
    required this.onCancelled,
    this.repairRequest,
  });

  @override
  MyRepairRequestDetailsState createState() => MyRepairRequestDetailsState();
}

class MyRepairRequestDetailsState extends State<MyRepairRequestDetails> {
  late LocalizationService localizationService;
  late ServicerService servicerService;
  Timestamp? _selectedOfferedTimeSlot;
  Timestamp? _servicerConfirmedTimeSlot;
  Timestamp? _selectedTimeSlot;
  VideoPlayerController? _videoController;
  bool _isFullScreenImage = false;
  int? _selectedImageIndex;
  bool _hasRatedServicer = false;
  int? _userRating;
  String? _servicerProfileImageUrl;
  String? _servicerFirstName;
  String? _servicerId;
  String? _randomFunFact;
  String? _userFcmToken;
  final List<Timestamp?> _offeredTimeSlots = [];
  RepairRequest? _repairRequest;
  String? _negotiatingServicerId;

  final TextEditingController _codeController = TextEditingController();
  String? _jobDescription;
  double? _jobPrice;
  bool _isCodeValid = false;
  bool _hasConfirmedJobTerms = false;

  @override
  void initState() {
    super.initState();
    localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    servicerService = Provider.of<ServicerService>(context, listen: false);

    if (widget.repairRequest != null) {
      _repairRequest = widget.repairRequest;
      _initializeData();
    } else {
      _fetchRepairRequestDetails();
    }
    _fetchAndUpdateUserFcmToken();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _initializeData() {
    _servicerConfirmedTimeSlot = _repairRequest?.servicerConfirmedTimeSlot;
    _selectedOfferedTimeSlot = _repairRequest?.selectedTimeSlot;
    _servicerId = _repairRequest?.servicerId;
    if (_servicerId != null) {
      _fetchServicerDetails();
    }
    _checkIfUserHasRated();
    _loadRandomFunFact();
  }

  Future<void> _fetchRepairRequestDetails() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('repair_requests')
          .where('id', isEqualTo: widget.repairRequestId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final DocumentSnapshot repairRequestSnapshot = querySnapshot.docs.first;
        final data = repairRequestSnapshot.data() as Map<String, dynamic>;

        setState(() {
          _repairRequest = RepairRequest.fromMap(data);
          _initializeData();
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _fetchAndUpdateUserFcmToken() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token!.isNotEmpty) {
        setState(() {
          _userFcmToken = token;
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': token});
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        setState(() {
          _userFcmToken = newToken;
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'fcmToken': newToken});
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _checkIfUserHasRated() async {
    if (_servicerId == null || widget.repairRequestId.isEmpty) return;
    try {
      final ratingDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_servicerId)
          .collection('ratings')
          .doc(widget.repairRequestId)
          .get();
      if (ratingDoc.exists) {
        setState(() {
          _hasRatedServicer = true;
          _userRating = ratingDoc['rating'] as int;
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _submitRating(int rating) async {
    if (_servicerId == null ||
        _servicerId!.isEmpty ||
        widget.repairRequestId.isEmpty) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_servicerId!)
          .collection('ratings')
          .doc(widget.repairRequestId)
          .set({'rating': rating, 'date': Timestamp.now()});
      if (!mounted) return;
      setState(() {
        _hasRatedServicer = true;
        _userRating = rating;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('thankYouForRating') ??
                'Hvala vam na ocjeni!',
          ),
        ),
      );
      await _fetchRepairRequestDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorSubmittingRating') ?? 'Došlo je do greške prilikom slanja vaše ocjene'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _cancelRequestWithReason() async {
    TextEditingController reasonController = TextEditingController();

    bool confirmCancel = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                localizationService.translate('cancelRequest') ??
                    "Otkaži zahtjev",
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizationService.translate('enterCancelReason') ??
                        "Unesite razlog otkazivanja:",
                  ),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText:
                          localizationService.translate('cancellationReason') ??
                              "Razlog otkazivanja",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localizationService.translate('no') ?? "Ne"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localizationService.translate('yes') ?? "Da"),
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
                "Razlog otkazivanja je obavezan.",
          ),
        ),
      );
      return;
    }

    DateTime now = DateTime.now();
    String repairRequestId = widget.repairRequestId;
    DocumentReference repairRequestRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(_repairRequest?.countryId ?? 'unknown_country')
        .collection('cities')
        .doc(_repairRequest?.cityId ?? 'unknown_city')
        .collection('repair_requests')
        .doc(repairRequestId);

    try {
      await repairRequestRef.collection('cancelled_requests').add({
        'userId': _repairRequest?.userId ?? '',
        'servicerId': _servicerId ?? '',
        'requestId': repairRequestId,
        'cancelledAt': Timestamp.fromDate(now),
        'reason': reason,
        'canceledBy': _servicerId != null ? 'servicer' : 'user',
      });

      await repairRequestRef.update({
        'servicerId': FieldValue.delete(),
        'selectedTimeSlot': FieldValue.delete(),
        'timeOfSelectedTimeSlot': FieldValue.delete(),
        'status': 'Cancelled',
        'CancelReason': reason,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('requestCancelled') ??
                'Zahtjev je uspješno otkazan.',
          ),
        ),
      );

      widget.onCancelled();
      await _fetchRepairRequestDetails();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorCancellingRequest') ?? 'Došlo je do greške'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _selectTimeSlot(Timestamp timeSlot, String servicerId) async {
    try {
      final now = Timestamp.now();
      String repairRequestId = widget.repairRequestId;
      DocumentReference repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_repairRequest?.countryId ?? 'unknown_country')
          .collection('cities')
          .doc(_repairRequest?.cityId ?? 'unknown_city')
          .collection('repair_requests')
          .doc(repairRequestId);

      await repairRequestRef.update({
        'servicerId': servicerId,
        'selectedTimeSlot': timeSlot,
        'timeOfSelectedTimeSlot': now,
        'status': 'waitingforconfirmation',
      });

      setState(() {
        _selectedOfferedTimeSlot = timeSlot;
        _selectedTimeSlot = now;
        _negotiatingServicerId = servicerId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('timeSlotSelected') ??
                'Termin je uspješno odabran.',
          ),
        ),
      );
      await _fetchRepairRequestDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorSelectingTimeSlot') ?? 'Došlo je do greške prilikom odabira termina'}: $e',
          ),
        ),
      );
    }
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

  Widget _buildStatusIconAndMessage() {
    String statusMessage = '';
    IconData statusIcon = Icons.info;
    Color iconColor = Colors.blue;

    final servicerOffers = _repairRequest?.servicerOffers ?? [];
    final selectedTimeSlot = _repairRequest?.selectedTimeSlot;
    final servicerConfirmedTimeSlot = _repairRequest?.servicerConfirmedTimeSlot;
    final status = _repairRequest?.status ?? '';

    if (status == 'waitingforconfirmation') {
      statusMessage = localizationService.translate('waitingForConfirmation') ??
          'Čekamo potvrdu termina.';
      statusIcon = Icons.hourglass_empty;
      iconColor = Colors.orangeAccent;
    } else if (servicerOffers.isNotEmpty && selectedTimeSlot == null) {
      if (status == 'Published_2') {
        statusMessage =
            localizationService.translate('chooseServicerArrivalTime') ??
                'Odaberite termin dolaska servisera.';
      } else {
        statusMessage = localizationService.translate('selectTimeSlot') ??
            'Odaberite termin.';
      }
      statusIcon = Icons.schedule;
      iconColor = Colors.orange;
    } else if (selectedTimeSlot != null && servicerConfirmedTimeSlot == null) {
      DateTime selectedDate = selectedTimeSlot.toDate();
      String formattedDate =
          '${_dayOfWeek(selectedDate.weekday)}, ${_formatTimestamp(selectedTimeSlot)} - ${_formatTime(selectedDate)}h';
      statusMessage = localizationService.translate('waitingForConfirmation') ??
          'Čekamo potvrdu servisera za $formattedDate.';
      statusIcon = Icons.hourglass_empty;
      iconColor = Colors.orangeAccent;
    } else if (servicerConfirmedTimeSlot != null && status != 'completed') {
      statusMessage = localizationService.translate('serviceConfirmed') ??
          'Servis je dogovoren!';
      statusIcon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (status == 'completed') {
      statusMessage = localizationService.translate('jobCompleted') ??
          'Posao je uspješno obavljen!';
      statusIcon = Icons.done_all;
      iconColor = Colors.green;
    } else if (servicerOffers.isEmpty) {
      statusMessage = localizationService.translate('searchingForServicer') ??
          'Tražimo servisera!';
      statusIcon = Icons.search;
      iconColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: iconColor, size: 50),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              statusMessage,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedArrivalInfo() {
    if (_servicerConfirmedTimeSlot == null) return const SizedBox.shrink();
    DateTime arrivalDate = _servicerConfirmedTimeSlot!.toDate();
    String arrivalDateText =
        '${_dayOfWeek(arrivalDate.weekday)}, ${_formatTimestamp(_servicerConfirmedTimeSlot!)} - ${_formatTime(arrivalDate)}h';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if ((_servicerProfileImageUrl != null &&
                    _servicerProfileImageUrl!.isNotEmpty) ||
                (_servicerFirstName != null &&
                    _servicerFirstName!.isNotEmpty)) ...[
              Row(
                children: [
                  if (_servicerProfileImageUrl != null &&
                      _servicerProfileImageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: CachedNetworkImage(
                        imageUrl: _servicerProfileImageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey,
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _servicerFirstName ??
                          localizationService.translate('servicerRequired') ??
                          'Potreban je serviser',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                localizationService.translate('arrivalTime') ??
                    'Vrijeme dolaska',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(arrivalDateText, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (_repairRequest?.status != 'completed' && !_hasConfirmedJobTerms)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.yellow[100],
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      localizationService.translate('enterCodeMessage') ??
                          'Upisivanjem koda koji će Vam dati serviser prikazat će Vam se dogovorena cijena i opis posla nakon čega ćete moći potvrditi dogovor i dati svoju suglasnost da se posao obavi.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText:
                              localizationService.translate('enterCode') ??
                                  'Unesite kod',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _checkCode,
                              child: Text(
                                localizationService.translate('checkCode') ??
                                    'Provjeri kod',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _scanQRCode,
                              child: Text(
                                localizationService.translate('scanQRCode') ??
                                    'Skeniraj QR kod',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isCodeValid && !_hasConfirmedJobTerms)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          localizationService.translate('jobTerms') ??
                              'Uvjeti posla',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizationService.translate('workDescription') ?? 'Opis posla'}: $_jobDescription',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizationService.translate('price') ?? 'Cijena'}: $_jobPrice €',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _confirmJobTerms,
                          child: Text(
                            localizationService.translate('confirmJobTerms') ??
                                'Potvrdi uvjete posla',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkCode() async {
    String enteredCode = _codeController.text.trim();
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('enterValidCode') ??
                'Molimo unesite kod.',
          ),
        ),
      );
      return;
    }

    try {
      if (_servicerId == null || _servicerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('servicerNotFound') ??
                  'Serviser nije pronađen.',
            ),
          ),
        );
        return;
      }
      final jobDocs = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_servicerId)
          .collection('jobs')
          .where('repairRequestId', isEqualTo: _repairRequest?.id)
          .get();
      if (jobDocs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('jobDetailsNotFound') ??
                  'Detalji posla nisu pronađeni.',
            ),
          ),
        );
        return;
      }
      final jobData = jobDocs.docs.first.data();
      String uniqueCode = jobData['uniqueCode'] ?? '';
      if (enteredCode.toUpperCase() == uniqueCode.toUpperCase()) {
        setState(() {
          _isCodeValid = true;
          _jobDescription = jobData['workDescription'];
          _jobPrice = jobData['price'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('codeValid') ?? 'Kod je ispravan.',
            ),
          ),
        );
      } else {
        setState(() {
          _isCodeValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('codeInvalid') ??
                  'Kod je neispravan.',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorCheckingCode') ?? 'Došlo je do greške prilikom provjere koda'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _confirmJobTerms() async {
    try {
      String repairRequestId = widget.repairRequestId;
      DocumentReference repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_repairRequest?.countryId ?? 'unknown_country')
          .collection('cities')
          .doc(_repairRequest?.cityId ?? 'unknown_city')
          .collection('repair_requests')
          .doc(repairRequestId);

      if (_servicerId == null || _servicerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('servicerNotFound') ??
                  'Serviser nije pronađen.',
            ),
          ),
        );
        return;
      }

      QuerySnapshot servicerJobsSnapshot = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_servicerId!)
          .collection('jobs')
          .where('repairRequestId', isEqualTo: repairRequestId)
          .get();
      if (servicerJobsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('jobDetailsNotFound') ??
                  'Detalji posla nisu pronađeni kod servisera.',
            ),
          ),
        );
        return;
      }
      DocumentReference servicerJobRef =
          servicerJobsSnapshot.docs.first.reference;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(repairRequestRef, {'status': 'completed'});
      batch.update(servicerJobRef, {'status': 'completed'});
      await batch.commit();

      setState(() {
        _hasConfirmedJobTerms = true;
        _repairRequest = _repairRequest?.copyWith(status: 'completed');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('jobConfirmed') ??
                'Posao je potvrđen.',
          ),
        ),
      );
      await _fetchRepairRequestDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorConfirmingJob') ?? 'Došlo je do greške prilikom potvrde posla'}: $e',
          ),
        ),
      );
    }
  }

  Widget _buildServicerOffersSection() {
    final localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('countries')
          .doc(_repairRequest?.countryId ?? 'unknown_country')
          .collection('cities')
          .doc(_repairRequest?.cityId ?? 'unknown_city')
          .collection('repair_requests')
          .doc(widget.repairRequestId)
          .collection('servicerOffers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              localizationService.translate('noOffersYet') ??
                  'Još nema ponuda.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }
        final offers = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offerDoc = offers[index];
            final offer = offerDoc.data() as Map<String, dynamic>;
            final servicerId = offer['servicerId'] ?? '';
            final timeSlots = offer['timeSlots'] as List<dynamic>? ?? [];
            final timestamp = offer['createdAt'] is Timestamp
                ? offer['createdAt'] as Timestamp
                : null;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('servicers')
                  .doc(servicerId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final servicerData =
                    snapshot.data!.data() as Map<String, dynamic>;
                final servicerName = servicerData['firstName'] ?? 'Serviser';
                final servicerProfileImageUrl =
                    servicerData['personalIdUrl'] ?? '';
                final isNegotiatingWithThisServicer =
                    _negotiatingServicerId == servicerId;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(
                      color: isNegotiatingWithThisServicer
                          ? Colors.orange.shade200
                          : Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (servicerProfileImageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: CachedNetworkImage(
                                  imageUrl: servicerProfileImageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey,
                                    child: const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                servicerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizationService.translate('offeredTimeSlots') ??
                              'Ponuđeni termini:',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: timeSlots.map((slot) {
                            final dateTime = (slot as Timestamp).toDate();
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_dayOfWeek(dateTime.weekday)}, ${_formatTimestamp(slot)} - ${_formatTime(dateTime)}h',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _negotiatingServicerId != null
                                      ? null
                                      : () => _selectTimeSlot(
                                            slot,
                                            servicerId,
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                  ),
                                  child: Text(
                                    localizationService.translate('select') ??
                                        'Odaberi',
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        if (timestamp != null)
                          Text(
                            '${localizationService.translate('offerSentAt') ?? 'Ponuda poslana u'}: ${_formatTimestamp(timestamp)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _fetchServicerDetails() async {
    if (_servicerId == null || _servicerId!.isEmpty) return;
    try {
      DocumentSnapshot servicerSnapshot = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_servicerId)
          .get();
      if (servicerSnapshot.exists) {
        Map<String, dynamic> servicerData =
            servicerSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _servicerFirstName = servicerData['firstName'] as String? ?? '';
          _servicerProfileImageUrl =
              servicerData['personalIdUrl'] as String? ?? '';
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _loadRandomFunFact() async {
    final List<String> funFactKeys = [
      'funfact.1.content',
      'funfact.2.content',
      'funfact.3.content',
    ];

    final randomIndex = Random().nextInt(funFactKeys.length);
    final randomKey = funFactKeys[randomIndex];

    setState(() {
      _randomFunFact = localizationService.translate(randomKey);
    });
  }

  Widget _buildFunFactCard() {
    if (_randomFunFact == null) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb, color: Colors.amber, size: 40),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizationService.translate('funFact') ?? 'Zanimljivost',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(_randomFunFact!, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    if (_servicerConfirmedTimeSlot == null ||
        _repairRequest?.status != 'completed') {
      return const SizedBox.shrink();
    }
    if (_hasRatedServicer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          localizationService.translate('thankYouForRating') ??
              'Hvala vam na ocjeni',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizationService.translate('rateServicer') ??
              'Ocijenite servisera',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                Icons.star,
                color: _userRating != null && _userRating! > index
                    ? Colors.orange
                    : Colors.grey,
              ),
              onPressed: () {
                _submitRating(index + 1);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildImagesAndVideo() {
    if (_repairRequest == null) return const SizedBox.shrink();
    List<String> imagePaths = _repairRequest!.imagePaths;
    String? videoPath = _repairRequest!.videoPath;
    List<Widget> mediaWidgets = [];

    if (imagePaths.isNotEmpty) {
      mediaWidgets.add(
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: imagePaths.map((path) {
            int index = imagePaths.indexOf(path);
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
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image),
              ),
            );
          }).toList(),
        ),
      );
    }

    if (videoPath != null && videoPath.isNotEmpty) {
      mediaWidgets.add(
        GestureDetector(
          onTap: () {
            if (_videoController != null &&
                _videoController!.value.isInitialized) {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            }
          },
          child: Container(
            width: 100,
            height: 100,
            color: Colors.black54,
            child: _videoController != null &&
                    _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mediaWidgets,
    );
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
              imageUrl: (_repairRequest?.imagePaths.elementAt(
                    _selectedImageIndex!,
                  ) ??
                  ''),
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image,
                size: 100,
                color: Colors.grey,
              ),
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

  Future<void> _scanQRCode() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Korisnik nije prijavljen.')),
      );
      return;
    }

    final userData = await UserService().getUserDocument(currentUser);
    final username = userData?['username'] ?? 'anonimus';

    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(username: username),
      ),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _codeController.text = scannedCode;
      });
      _checkCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_repairRequest == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizationService.translate('details') ?? 'Detalji'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    String status = _repairRequest?.status ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('details') ?? 'Detalji'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusIconAndMessage(),
              const SizedBox(height: 16.0),
              _buildConfirmedArrivalInfo(),
              const SizedBox(height: 8.0),
              if (_selectedOfferedTimeSlot == null &&
                  (status == 'Published' ||
                      status == 'In Negotiations' ||
                      status == 'Published_2'))
                _buildServicerOffersSection(),
              _buildFunFactCard(),
              const SizedBox(height: 16.0),
              Text(
                '${localizationService.translate('reportTitle') ?? 'Prijava'} #${_repairRequest?.reportNumber ?? ''}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                '${localizationService.translate('description') ?? 'Opis'}: ${_repairRequest?.description ?? ''}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16.0),
              _buildImagesAndVideo(),
              const SizedBox(height: 16.0),
              _buildRatingSection(),
              const SizedBox(height: 16.0),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatTimestamp(
                    _repairRequest?.requestedDate != null
                        ? Timestamp.fromDate(_repairRequest!.requestedDate)
                        : Timestamp.now(),
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: _cancelRequestWithReason,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(
                    localizationService.translate('cancelRequest') ??
                        'Otkaži zahtjev',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
