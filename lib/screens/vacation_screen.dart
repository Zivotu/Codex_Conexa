// lib/screens/vacation_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/parking_schedule_service.dart';
import '../models/parking_slot.dart';

class VacationScreen extends StatefulWidget {
  final List<ParkingSlot> userParkingSlots;
  final String countryId;
  final String cityId;
  final String locationId;

  const VacationScreen({
    super.key,
    required this.userParkingSlots,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _VacationScreenState createState() => _VacationScreenState();
}

class _VacationScreenState extends State<VacationScreen> {
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();
  final Map<String, VacationSettings> _vacationSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initVacation();
  }

  Future<void> _initVacation() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    for (var slot in widget.userParkingSlots) {
      VacationSettings vs = VacationSettings();
      if (slot.vacation != null) {
        vs.hasVacation = true;
        vs.startDate = slot.vacation!.startDate;
        vs.endDate = slot.vacation!.endDate;
      } else {
        vs.hasVacation = false;
        vs.startDate = null;
        vs.endDate = null;
      }
      _vacationSettings[slot.id] = vs;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveVacation() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    for (var slot in widget.userParkingSlots) {
      var vs = _vacationSettings[slot.id]!;
      if (vs.hasVacation && vs.startDate != null && vs.endDate != null) {
        await _parkingScheduleService.defineVacation(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlotId: slot.id,
          startDate: vs.startDate!,
          endDate: vs.endDate!,
        );
      } else {
        await _parkingScheduleService.removeVacation(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlotId: slot.id,
        );
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Godišnji spremljen.')));
    Navigator.pop(context);
  }

  Future<void> _pickStartDate(String slotId) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    setState(() {
      _vacationSettings[slotId]!.startDate = picked;
    });
  }

  Future<void> _pickEndDate(String slotId) async {
    DateTime now = DateTime.now();
    DateTime start = _vacationSettings[slotId]!.startDate ?? now;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start,
      lastDate: DateTime(now.year + 2),
    );
    setState(() {
      _vacationSettings[slotId]!.endDate = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Idem na godišnji')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Idem na godišnji')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children:
              widget.userParkingSlots.map((slot) {
                final vs = _vacationSettings[slot.id]!;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Godišnji aktivan'),
                          value: vs.hasVacation,
                          onChanged: (val) {
                            setState(() {
                              vs.hasVacation = val;
                              if (!val) {
                                vs.startDate = null;
                                vs.endDate = null;
                              }
                            });
                          },
                        ),
                        if (vs.hasVacation) ...[
                          ListTile(
                            title: const Text('Datum početka'),
                            subtitle:
                                vs.startDate != null
                                    ? Text(
                                      '${vs.startDate!.day.toString().padLeft(2, '0')}.${vs.startDate!.month.toString().padLeft(2, '0')}.${vs.startDate!.year}',
                                    )
                                    : const Text('Nije odabran'),
                            trailing: TextButton(
                              onPressed: () => _pickStartDate(slot.id),
                              child: const Text('Odaberi'),
                            ),
                          ),
                          ListTile(
                            title: const Text('Datum završetka'),
                            subtitle:
                                vs.endDate != null
                                    ? Text(
                                      '${vs.endDate!.day.toString().padLeft(2, '0')}.${vs.endDate!.month.toString().padLeft(2, '0')}.${vs.endDate!.year}',
                                    )
                                    : const Text('Nije odabran'),
                            trailing: TextButton(
                              onPressed: () => _pickEndDate(slot.id),
                              child: const Text('Odaberi'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveVacation,
        child: const Icon(Icons.save),
      ),
    );
  }
}

class VacationSettings {
  bool hasVacation = false;
  DateTime? startDate;
  DateTime? endDate;
}
