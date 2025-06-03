// lib/widgets/time_slot_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/time_frame.dart';
import '../services/localization_service.dart';

class TimeSlotSelectionDialog extends StatefulWidget {
  final List<TimeFrame> userTimeFrames;

  const TimeSlotSelectionDialog({
    super.key,
    required this.userTimeFrames,
  });

  @override
  _TimeSlotSelectionDialogState createState() =>
      _TimeSlotSelectionDialogState();
}

class _TimeSlotSelectionDialogState extends State<TimeSlotSelectionDialog> {
  final List<Timestamp> _selectedSlots = [];

  final List<DateTime> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableSlots();
  }

  void _generateAvailableSlots() {
    _availableSlots.clear();
    final now = DateTime.now();
    final next7Days = List<DateTime>.generate(
        7, (index) => DateTime(now.year, now.month, now.day + index));

    for (var day in next7Days) {
      for (var timeFrame in widget.userTimeFrames) {
        final startHour = timeFrame.startHour;
        final endHour = timeFrame.endHour;
        for (var hour = startHour; hour < endHour; hour++) {
          final slot = DateTime(day.year, day.month, day.day, hour);
          _availableSlots.add(slot);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return AlertDialog(
          title: Text(localizationService.translate('selectTimeSlots')),
          content: SingleChildScrollView(
            child: Column(
              children: _availableSlots.map((slot) {
                return CheckboxListTile(
                  title: Text(_formatDateTime(slot, localizationService)),
                  value: _selectedSlots.contains(Timestamp.fromDate(slot)),
                  onChanged: (value) {
                    setState(() {
                      if (value!) {
                        _selectedSlots.add(Timestamp.fromDate(slot));
                      } else {
                        _selectedSlots.removeWhere(
                            (timestamp) => timestamp.toDate() == slot);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_selectedSlots);
              },
              child: Text(localizationService.translate('submit')),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(
      DateTime dateTime, LocalizationService localizationService) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${localizationService.translate(_dayOfWeek(dateTime.weekday))} - ${dateTime.hour}:00h';
  }

  String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return '';
    }
  }
}
