// lib/widgets/time_slot_options.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Dodaj provider import
import '../services/localization_service.dart';

class TimeSlotOptions extends StatelessWidget {
  final Map<String, String> timeSlots;
  final List<String> selectedTimeSlots;
  final Function(List<String>) onChanged;

  const TimeSlotOptions({
    super.key,
    required this.timeSlots,
    required this.selectedTimeSlots,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Pristupanje LocalizationService putem Provider-a
    final localizationService = Provider.of<LocalizationService>(context);

    return Column(
      children: timeSlots.entries.map((entry) {
        final key = entry.key;
        final label = localizationService.translate(entry.value);
        return CheckboxListTile(
          title: Text(label),
          value: selectedTimeSlots.contains(key),
          onChanged: (value) {
            if (value == null) return;
            List<String> updatedSlots = List.from(selectedTimeSlots);
            if (value) {
              if (!updatedSlots.contains(key)) {
                updatedSlots.add(key);
              }
            } else {
              updatedSlots.remove(key);
            }
            onChanged(updatedSlots);
          },
        );
      }).toList(),
    );
  }
}
