// lib/models/permanent_availability.dart

import 'package:flutter/material.dart';

class PermanentAvailability {
  final bool isEnabled;
  final List<String> days;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  PermanentAvailability({
    required this.isEnabled,
    required this.days,
    required this.startTime,
    required this.endTime,
  });

  factory PermanentAvailability.fromMap(Map<String, dynamic> map) {
    return PermanentAvailability(
      isEnabled: map['isEnabled'] ?? false,
      days: List<String>.from(map['days'] ?? []),
      startTime: _parseTime(map['startTime'] ?? '00:00'),
      endTime: _parseTime(map['endTime'] ?? '23:59'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'days': days,
      'startTime':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    };
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    return TimeOfDay(hour: h, minute: m);
  }
}
