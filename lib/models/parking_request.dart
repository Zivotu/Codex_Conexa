import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingRequest {
  final String requestId;
  final String requesterId;
  final int numberOfSpots;
  final DateTime startDate;
  final String startTime;
  final DateTime endDate;
  final String endTime;
  final String status;
  final String message;
  final String countryId;
  final String cityId;
  final String locationId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final List<String> assignedSlots;

  ParkingRequest({
    required this.requestId,
    required this.requesterId,
    required this.numberOfSpots,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.status,
    this.message = '',
    required this.countryId,
    required this.cityId,
    required this.locationId,
    this.approvedBy,
    this.approvedAt,
    this.assignedSlots = const [],
  });

  // Getter za provjeru je li zahtjev istekao
  bool get isExpired {
    // Provjera na temelju krajnjeg datuma i vremena
    final now = DateTime.now();
    final endDateTime = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      int.parse(endTime.split(':')[0]),
      int.parse(endTime.split(':')[1]),
    );
    return endDateTime.isBefore(now);
  }

  // Ispravljena fromMap metoda
  factory ParkingRequest.fromMap(Map<String, dynamic> map, String docId) {
    return ParkingRequest(
      requestId: docId,
      requesterId: map['requesterId'] ?? '',
      numberOfSpots: map['numberOfSpots'] ?? 0,
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      startTime: map['startTime'] ?? '00:00',
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: map['endTime'] ?? '23:59',
      status: map['status'] ?? 'pending',
      message: map['message'] ?? '',
      countryId: map['countryId'] ?? '',
      cityId: map['cityId'] ?? '',
      locationId: map['locationId'] ?? '',
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      assignedSlots: List<String>.from(map['assignedSlots'] ?? []),
    );
  }

  ParkingRequest copyWith({
    String? requestId,
    String? requesterId,
    int? numberOfSpots,
    DateTime? startDate,
    String? startTime,
    DateTime? endDate,
    String? endTime,
    String? status,
    String? message,
    String? countryId,
    String? cityId,
    String? locationId,
    String? approvedBy,
    DateTime? approvedAt,
    List<String>? assignedSlots,
  }) {
    return ParkingRequest(
      requestId: requestId ?? this.requestId,
      requesterId: requesterId ?? this.requesterId,
      numberOfSpots: numberOfSpots ?? this.numberOfSpots,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endDate: endDate ?? this.endDate,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      message: message ?? this.message,
      countryId: countryId ?? this.countryId,
      cityId: cityId ?? this.cityId,
      locationId: locationId ?? this.locationId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      assignedSlots: assignedSlots ?? this.assignedSlots,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requesterId': requesterId,
      'numberOfSpots': numberOfSpots,
      'startDate': Timestamp.fromDate(startDate),
      'startTime': startTime,
      'endDate': Timestamp.fromDate(endDate),
      'endTime': endTime,
      'status': status,
      'message': message,
      'countryId': countryId,
      'cityId': cityId,
      'locationId': locationId,
      'assignedSlots': assignedSlots,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }
}
