// lib/widgets/time_slot_picker.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Dodaj provider import
import '../services/localization_service.dart';
import 'package:intl/intl.dart';

class TimeSlotPicker extends StatelessWidget {
  final Timestamp? selectedTimeSlot;
  final Function() onSelect;
  final Function() onDelete;

  const TimeSlotPicker({
    super.key,
    required this.selectedTimeSlot,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Pristupanje LocalizationService putem Provider-a
    final localizationService = Provider.of<LocalizationService>(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(
          selectedTimeSlot != null
              ? DateFormat('dd.MM.yyyy - HH:mm')
                  .format(selectedTimeSlot!.toDate())
              : localizationService.translate('selectTimeSlot') ??
                  'Odaberi termin',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: onSelect,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
