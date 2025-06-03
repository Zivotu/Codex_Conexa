// lib/screens/request_parking_screen.dart

import 'package:flutter/material.dart';
import '../models/parking_slot.dart';
import '../services/parking_schedule_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestParkingScreen extends StatefulWidget {
  final List<ParkingSlot> userParkingSlots;
  final String countryId;
  final String cityId;
  final String locationId;

  const RequestParkingScreen({
    super.key,
    required this.userParkingSlots,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _RequestParkingScreenState createState() => _RequestParkingScreenState();
}

class _RequestParkingScreenState extends State<RequestParkingScreen> {
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();
  final _formKey = GlobalKey<FormState>();

  int? _numberOfSpots;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Pomoćna metoda za formatiranje TimeOfDay u 'HH:mm' string
  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Provjera da su svi potrebni podaci uneseni
      if (_startDate == null ||
          _startTime == null ||
          _endDate == null ||
          _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Molimo unesite sve potrebne informacije.'),
          ),
        );
        return;
      }

      // Provjera da je endDate nakon startDate
      if (_endDate!.isBefore(_startDate!) ||
          (_endDate!.isAtSameMomentAs(_startDate!) &&
              (_endTime!.hour < _startTime!.hour ||
                  (_endTime!.hour == _startTime!.hour &&
                      _endTime!.minute <= _startTime!.minute)))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Datum i vrijeme završetka moraju biti nakon datuma i vremena početka.',
            ),
          ),
        );
        return;
      }

      String userId = FirebaseAuth.instance.currentUser!.uid;

      try {
        await _parkingScheduleService.createParkingRequest(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          numberOfSpots: _numberOfSpots!,
          startDate: _startDate!,
          startTime: _formatTimeOfDay(_startTime!), // IZMJENA: Dodano
          endDate: _endDate!,
          endTime: _formatTimeOfDay(_endTime!), // IZMJENA: Dodano
          message: null, // Ili dodajte polje za poruku ako je potrebno
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahtjev poslan. Čekajte odobrenje.')),
        );
        Navigator.pop(context);
      } catch (e) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Greška'),
                content: Text(
                  'Došlo je do greške prilikom slanja zahtjeva: $e',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zatraži parkirno mjesto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Dodano za skrolanje ako je potrebno
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Broj potrebnih parkirnih mjesta',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Molimo unesite broj parkirnih mjesta';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Molimo unesite ispravan broj';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _numberOfSpots = int.parse(value!);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Datum početka'),
                  trailing: TextButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 1),
                      );
                      setState(() {
                        _startDate = picked;
                      });
                    },
                    child: Text(
                      _startDate != null
                          ? '${_startDate!.day.toString().padLeft(2, '0')}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.year}'
                          : 'Odaberi datum',
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Vrijeme početka'),
                  trailing: TextButton(
                    onPressed: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _startTime = picked;
                        });
                      }
                    },
                    child: Text(
                      _startTime != null
                          ? _startTime!.format(context)
                          : 'Odaberi vrijeme',
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Datum završetka'),
                  trailing: TextButton(
                    onPressed: () async {
                      DateTime initialDate = _startDate ?? DateTime.now();
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: initialDate,
                        lastDate: DateTime(DateTime.now().year + 1),
                      );
                      setState(() {
                        _endDate = picked;
                      });
                    },
                    child: Text(
                      _endDate != null
                          ? '${_endDate!.day.toString().padLeft(2, '0')}.${_endDate!.month.toString().padLeft(2, '0')}.${_endDate!.year}'
                          : 'Odaberi datum',
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Vrijeme završetka'),
                  trailing: TextButton(
                    onPressed: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _endTime = picked;
                        });
                      }
                    },
                    child: Text(
                      _endTime != null
                          ? _endTime!.format(context)
                          : 'Odaberi vrijeme',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitRequest,
                  child: const Text('Pošalji zahtjev'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
