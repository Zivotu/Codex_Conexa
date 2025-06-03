// lib/providers/time_slot_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlotProvider with ChangeNotifier {
  final List<Timestamp?> _selectedTimeSlots = [null, null];

  TimeSlotProvider() {
    print('TimeSlotProvider initialized with: $_selectedTimeSlots');
  }

  List<Timestamp?> get selectedTimeSlots {
    print('Accessing selectedTimeSlots: $_selectedTimeSlots');
    return List.unmodifiable(_selectedTimeSlots);
  }

  void updateTimeSlot(int index, Timestamp? timestamp) {
    if (index >= 0 && index < _selectedTimeSlots.length) {
      _selectedTimeSlots[index] = timestamp;
      print('TimeSlot at index $index updated to $timestamp');
      notifyListeners();
    } else {
      print('Attempted to update invalid index: $index');
    }
  }

  void removeTimeSlot(int index) {
    if (index >= 0 && index < _selectedTimeSlots.length) {
      _selectedTimeSlots[index] = null;
      print('TimeSlot at index $index removed (set to null)');
      notifyListeners();
    } else {
      print('Attempted to remove invalid index: $index');
    }
  }

  void clearTimeSlots() {
    for (int i = 0; i < _selectedTimeSlots.length; i++) {
      _selectedTimeSlots[i] = null;
    }
    print('All time slots cleared: $_selectedTimeSlots');
    notifyListeners();
  }
}
