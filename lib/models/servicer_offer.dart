// lib/models/servicer_offer.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ServicerOffer {
  final String userId;
  final String servicerId; // Dodajemo `servicerId` polje
  final List<Timestamp> timeSlots;

  ServicerOffer({
    required this.userId,
    required this.servicerId, // Dodajemo `servicerId` parametar
    required this.timeSlots,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'servicerId': servicerId,
      'timeSlots': timeSlots,
    };
  }

  factory ServicerOffer.fromMap(Map<String, dynamic> map) {
    return ServicerOffer(
      userId: map['userId'] ?? '',
      servicerId: map['servicerId'] ?? '',
      timeSlots: List<Timestamp>.from(map['timeSlots'] ?? []),
    );
  }
}
