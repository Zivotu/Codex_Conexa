// lib/screens/define_availability_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/parking_schedule_service.dart';
import '../models/parking_slot.dart';
import '../services/localization_service.dart';

class DefineAvailabilityScreen extends StatefulWidget {
  final List<ParkingSlot> userParkingSlots;
  final String countryId;
  final String cityId;
  final String locationId;

  const DefineAvailabilityScreen({
    super.key,
    required this.userParkingSlots,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _DefineAvailabilityScreenState createState() =>
      _DefineAvailabilityScreenState();
}

class _DefineAvailabilityScreenState extends State<DefineAvailabilityScreen> {
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();

  final Map<String, SlotSettings> _slotSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    for (var slot in widget.userParkingSlots) {
      SlotSettings s = SlotSettings();
      // Initialize Availability Settings
      PermanentAvailability? pa = slot.permanentAvailability;
      s.isEnabled = pa!.isEnabled;
      s.days = List<String>.from(pa.days);
      s.startTime = _parseTime(pa.startTime);
      s.endTime = _parseTime(pa.endTime);

      // Initialize Vacation Settings
      if (slot.vacation != null) {
        s.hasVacation = true;
        s.vacationStartDate = slot.vacation!.startDate;
        s.vacationEndDate = slot.vacation!.endDate;
      } else {
        s.hasVacation = false;
        s.vacationStartDate = null;
        s.vacationEndDate = null;
      }

      _slotSettings[slot.id] = s;
    }

    setState(() {
      _isLoading = false;
    });
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> _saveSettings() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    for (var slot in widget.userParkingSlots) {
      var settings = _slotSettings[slot.id]!;

      // Save Availability Settings
      if (settings.isEnabled) {
        await _parkingScheduleService.definePermanentAvailability(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlotId: slot.id,
          isEnabled: settings.isEnabled,
          days: settings.days,
          startTime: settings.startTime!,
          endTime: settings.endTime!,
        );
      } else {
        await _parkingScheduleService.removePermanentAvailability(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlotId: slot.id,
        );
      }

      // Save Vacation Settings
      if (settings.hasVacation &&
          settings.vacationStartDate != null &&
          settings.vacationEndDate != null) {
        await _parkingScheduleService.defineVacation(
          userId: userId,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          parkingSlotId: slot.id,
          startDate: settings.vacationStartDate!,
          endDate: settings.vacationEndDate!,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalizationService.instance.translate('settings_saved') ??
              'Settings saved',
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _pickStartDate(String slotId) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _slotSettings[slotId]!.vacationStartDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    setState(() {
      _slotSettings[slotId]!.vacationStartDate = picked;
    });
  }

  Future<void> _pickEndDate(String slotId) async {
    DateTime now = DateTime.now();
    DateTime start = _slotSettings[slotId]!.vacationStartDate ?? now;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _slotSettings[slotId]!.vacationEndDate ?? start,
      firstDate: start,
      lastDate: DateTime(now.year + 2),
    );
    setState(() {
      _slotSettings[slotId]!.vacationEndDate = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localization.translate('define_permanent_availability') ??
                'Define Permanent Availability',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localization.translate('define_permanent_availability') ??
              'Define Permanent Availability',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: widget.userParkingSlots.map((slot) {
            final settings = _slotSettings[slot.id]!;
            return Card(
              margin: const EdgeInsets.all(8.0),
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
                    // Availability Switch
                    SwitchListTile(
                      title: Text(
                        localization.translate('permanent_available') ??
                            'Permanent Availability',
                      ),
                      value: settings.isEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          settings.isEnabled = value;
                        });
                      },
                    ),
                    if (settings.isEnabled) ...[
                      // Days Selection
                      CheckboxListTile(
                        title: Text(
                          localization.translate('weekdays') ?? 'Weekdays',
                        ),
                        value: settings.days.contains('weekday'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              settings.days.add('weekday');
                            } else {
                              settings.days.remove('weekday');
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: Text(
                          localization.translate('weekends') ?? 'Weekends',
                        ),
                        value: settings.days.contains('weekend'),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              settings.days.add('weekend');
                            } else {
                              settings.days.remove('weekend');
                            }
                          });
                        },
                      ),
                      // Start Time
                      ListTile(
                        title: Text(
                          localization.translate('time_from') ?? 'Time from',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: settings.startTime ??
                                  const TimeOfDay(hour: 0, minute: 0),
                            );
                            if (picked != null) {
                              setState(() {
                                settings.startTime = picked;
                              });
                            }
                          },
                          child: Text(
                            settings.startTime != null
                                ? settings.startTime!.format(context)
                                : (localization.translate('select_time') ??
                                    'Select time'),
                          ),
                        ),
                      ),
                      // End Time
                      ListTile(
                        title: Text(
                          localization.translate('time_to') ?? 'Time to',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: settings.endTime ??
                                  const TimeOfDay(hour: 23, minute: 59),
                            );
                            if (picked != null) {
                              setState(() {
                                settings.endTime = picked;
                              });
                            }
                          },
                          child: Text(
                            settings.endTime != null
                                ? settings.endTime!.format(context)
                                : (localization.translate('select_time') ??
                                    'Select time'),
                          ),
                        ),
                      ),
                    ],
                    const Divider(),
                    // Vacation Switch
                    SwitchListTile(
                      title: Text(
                        localization.translate('vacation_active') ??
                            'Vacation Active',
                      ),
                      value: settings.hasVacation,
                      onChanged: (bool value) {
                        setState(() {
                          settings.hasVacation = value;
                          if (!value) {
                            settings.vacationStartDate = null;
                            settings.vacationEndDate = null;
                          }
                        });
                      },
                    ),
                    if (settings.hasVacation) ...[
                      // Vacation Start Date
                      ListTile(
                        title: Text(
                          localization.translate('vacation_start_date') ??
                              'Vacation Start Date',
                        ),
                        subtitle: settings.vacationStartDate != null
                            ? Text(
                                '${settings.vacationStartDate!.day.toString().padLeft(2, '0')}.${settings.vacationStartDate!.month.toString().padLeft(2, '0')}.${settings.vacationStartDate!.year}',
                              )
                            : Text(
                                localization.translate(
                                      'date_not_selected',
                                    ) ??
                                    'Date not selected',
                              ),
                        trailing: TextButton(
                          onPressed: () => _pickStartDate(slot.id),
                          child: Text(
                            localization.translate('select') ?? 'Select',
                          ),
                        ),
                      ),
                      // Vacation End Date
                      ListTile(
                        title: Text(
                          localization.translate('vacation_end_date') ??
                              'Vacation End Date',
                        ),
                        subtitle: settings.vacationEndDate != null
                            ? Text(
                                '${settings.vacationEndDate!.day.toString().padLeft(2, '0')}.${settings.vacationEndDate!.month.toString().padLeft(2, '0')}.${settings.vacationEndDate!.year}',
                              )
                            : Text(
                                localization.translate(
                                      'date_not_selected',
                                    ) ??
                                    'Date not selected',
                              ),
                        trailing: TextButton(
                          onPressed: () => _pickEndDate(slot.id),
                          child: Text(
                            localization.translate('select') ?? 'Select',
                          ),
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
        onPressed: _saveSettings,
        tooltip: localization.translate('save_settings') ?? 'Save Settings',
        child: const Icon(Icons.save),
      ),
    );
  }
}

class SlotSettings {
  // Availability Settings
  bool isEnabled = false;
  List<String> days = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // Vacation Settings
  bool hasVacation = false;
  DateTime? vacationStartDate;
  DateTime? vacationEndDate;
}
