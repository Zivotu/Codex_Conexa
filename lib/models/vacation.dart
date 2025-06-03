// lib/models/vacation.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Vacation {
  final DateTime startDate;
  final DateTime endDate;

  Vacation({
    required this.startDate,
    required this.endDate,
  });

  factory Vacation.fromMap(Map<String, dynamic> map) {
    return Vacation(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
