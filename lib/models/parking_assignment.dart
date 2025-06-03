// lib/models/parking_assignment.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Assignment {
  final String assignmentId;
  final String slotId;
  final String requestId;
  final String requesterId;
  final DateTime startDate;
  final DateTime endDate;

  Assignment({
    required this.assignmentId,
    required this.slotId,
    required this.requestId,
    required this.requesterId,
    required this.startDate,
    required this.endDate,
  });

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      assignmentId: map['assignmentId'] ?? '',
      slotId: map['slotId'] ?? '',
      requestId: map['requestId'] ?? '',
      requesterId: map['requesterId'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'slotId': slotId,
      'requestId': requestId,
      'requesterId': requesterId,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
