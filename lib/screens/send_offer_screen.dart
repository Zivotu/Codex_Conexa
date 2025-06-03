// lib/screens/send_offer_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../models/repair_request.dart';
import '../services/localization_service.dart';
import 'servicer_dashboard_screen.dart';

final Logger _logger = Logger();

class SendOfferScreen extends StatefulWidget {
  final RepairRequest repairRequest;
  final String servicerId;

  const SendOfferScreen({
    super.key,
    required this.repairRequest,
    required this.servicerId,
  });

  @override
  State<SendOfferScreen> createState() => _SendOfferScreenState();
}

class _SendOfferScreenState extends State<SendOfferScreen> {
  Timestamp? _timeSlot1;
  Timestamp? _timeSlot2;

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    _logger.d('Building SendOfferScreen');
    _logger.d('selectedTimeSlots length: ${[
      _timeSlot1,
      _timeSlot2
    ].where((slot) => slot != null).length}');
    _logger.d('selectedTimeSlots content: [$_timeSlot1, $_timeSlot2]');

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('sendOffer') ?? 'Send Offer'),
      ),
      body: Column(
        children: [
          // Button for the first time slot
          Expanded(
            child: GestureDetector(
              onTap: () => _selectTime(context, 1),
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: _timeSlot1 != null
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: _timeSlot1 != null ? Colors.green : Colors.blue,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    _timeSlot1 != null
                        ? _formatSelectedTime(_timeSlot1!)
                        : localizationService.translate('chooseTimeSlot') ??
                            'Choose Time Slot',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Button for the second time slot
          Expanded(
            child: GestureDetector(
              onTap: () => _selectTime(context, 2),
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: _timeSlot2 != null
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: _timeSlot2 != null ? Colors.green : Colors.blue,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    _timeSlot2 != null
                        ? _formatSelectedTime(_timeSlot2!)
                        : localizationService.translate('chooseTimeSlot') ??
                            'Choose Time Slot',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Submit offer button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _submitOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(
                localizationService.translate('sendOfferButton') ??
                    'Pošalji ponudu',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, int slotNumber) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        final selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        if (widget.repairRequest.isWithinTimeFrames(selectedDateTime)) {
          setState(() {
            if (slotNumber == 1) {
              _timeSlot1 = Timestamp.fromDate(selectedDateTime);
              _logger.d('TimeSlot1 updated to $_timeSlot1');
            } else if (slotNumber == 2) {
              _timeSlot2 = Timestamp.fromDate(selectedDateTime);
              _logger.d('TimeSlot2 updated to $_timeSlot2');
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizationService
                      .translate('timeSlotOutOfRange') ??
                  'Odabrani termin je izvan dozvoljenog vremenskog okvira.'),
            ),
          );
        }
      }
    }
  }

  String _formatSelectedTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} - ${_weekdayName(dateTime.weekday)}, ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

  String _weekdayName(int weekday) {
    const weekdays = [
      'Ponedjeljak',
      'Utorak',
      'Srijeda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedjelja'
    ];
    return weekdays[weekday - 1];
  }

  Future<void> _submitOffer() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
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

    if (_timeSlot1 == null && _timeSlot2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('pleaseFillAllFields') ??
              'Odaberite barem jedan termin.'),
        ),
      );
      return;
    }

    final List<Timestamp> filteredTimeSlots = [];
    if (_timeSlot1 != null) filteredTimeSlots.add(_timeSlot1!);
    if (_timeSlot2 != null) filteredTimeSlots.add(_timeSlot2!);

    // Prikaži progress bar
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(localizationService.translate('sendingOffer') ??
                    'Šaljem ponudu...'),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Fetch servicer details
      final servicerDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(widget.servicerId)
          .get();

      String servicerName = 'Serviser';
      String servicerProfileImageUrl = '';

      if (servicerDoc.exists) {
        servicerName = servicerDoc['firstName'] ?? 'Serviser';
        servicerProfileImageUrl = servicerDoc['profileImageUrl'] ?? '';
      }

      final repairRequestRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.repairRequest.countryId)
          .collection('cities')
          .doc(widget.repairRequest.cityId)
          .collection('repair_requests')
          .doc(widget.repairRequest.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot repairRequestSnapshot =
            await transaction.get(repairRequestRef);

        if (!repairRequestSnapshot.exists) {
          throw Exception('Zahtjev za popravak ne postoji.');
        }

        Map<String, dynamic> repairRequestData =
            repairRequestSnapshot.data() as Map<String, dynamic>;

        if (repairRequestData['status'] != 'Published') {
          throw Exception('Zahtjev za popravak nije dostupan za ponude.');
        }

        int currentTotalOffers = repairRequestData['totalOffers'] ?? 0;

        if (currentTotalOffers >= 11) {
          throw Exception(
              'Zahtjev za popravak je već dosegao maksimalni broj ponuda.');
        }

        CollectionReference servicerOffersRef =
            repairRequestRef.collection('servicerOffers');
        DocumentReference newOfferRef = servicerOffersRef.doc();

        Map<String, dynamic> offerData = {
          'timeSlots': filteredTimeSlots,
          'servicerId': widget.servicerId,
          'servicerName': servicerName,
          'servicerProfileImageUrl': servicerProfileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(newOfferRef, offerData);

        int newTotalOffers = currentTotalOffers + 1;
        transaction.update(repairRequestRef, {
          'totalOffers': newTotalOffers,
          'servicerIds': FieldValue.arrayUnion([widget.servicerId]),
          'status': 'Published_2', // Postavljanje statusa na "Published_2"
        });

        if (newTotalOffers >= 11) {
          transaction.update(repairRequestRef, {'status': 'Closed'});
        }
      });

      // Zatvori progress bar
      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizationService.translate('offerSent') ??
              'Ponuda uspješno poslana.'),
        ),
      );

      // Reset local state
      setState(() {
        _timeSlot1 = null;
        _timeSlot2 = null;
      });

      // Check if the widget is still mounted before navigating
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ServicerDashboardScreen(
            username: currentUser.displayName ?? 'Serviser',
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      _logger.e('Greška prilikom slanja ponude: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${localizationService.translate('errorSendingOffer') ?? 'Greška prilikom slanja ponude'}: $e'),
        ),
      );
    }
  }
}
