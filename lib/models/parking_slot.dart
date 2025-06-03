import 'package:cloud_firestore/cloud_firestore.dart';

class PermanentAvailability {
  final bool isEnabled;
  final List<String> days;
  final String startTime;
  final String endTime;

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
      startTime: map['startTime'] ?? '00:00',
      endTime: map['endTime'] ?? '23:59',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'days': days,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class VacationAvailability {
  final DateTime startDate;
  final DateTime endDate;

  VacationAvailability({
    required this.startDate,
    required this.endDate,
  });

  factory VacationAvailability.fromMap(Map<String, dynamic> map) {
    return VacationAvailability(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }
}

class ParkingSlot {
  final String id;
  final String name;
  final String ownerId;
  final String locationId; // Dodano
  final PermanentAvailability? permanentAvailability;
  final VacationAvailability? vacation;

  ParkingSlot({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.locationId, // Dodano
    this.permanentAvailability,
    this.vacation,
  });

  factory ParkingSlot.fromMap(Map<String, dynamic> map, String id) {
    return ParkingSlot(
      id: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      locationId: map['locationId'] ?? '', // Dodano
      permanentAvailability: map['permanentAvailability'] != null
          ? PermanentAvailability.fromMap(map['permanentAvailability'])
          : null,
      vacation: map['vacation'] != null
          ? VacationAvailability.fromMap(map['vacation'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'locationId': locationId, // Dodano
      if (permanentAvailability != null)
        'permanentAvailability': permanentAvailability!.toMap(),
      if (vacation != null) 'vacation': vacation!.toMap(),
    };
  }
}
