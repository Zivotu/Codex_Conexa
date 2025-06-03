// lib/providers/time_slot_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlotProvider with ChangeNotifier {
  final List<Timestamp?> _selectedTimeSlots = [];

  List<Timestamp?> get selectedTimeSlots => _selectedTimeSlots;

  void addTimeSlot() {
    _selectedTimeSlots.add(null);
    notifyListeners();
  }

  void removeTimeSlot(int index) {
    if (index >= 0 && index < _selectedTimeSlots.length) {
      _selectedTimeSlots.removeAt(index);
      notifyListeners();
    }
  }

  void updateTimeSlot(int index, Timestamp timestamp) {
    if (index >= 0 && index < _selectedTimeSlots.length) {
      _selectedTimeSlots[index] = timestamp;
      notifyListeners();
    }
  }

  void clearTimeSlots() {
    _selectedTimeSlots.clear();
    notifyListeners();
  }
}
