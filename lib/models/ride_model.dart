// lib/models/ride_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus { open, requested, active, completed, canceled }

class Ride {
  final String rideId;
  final String driverId;
  final String driverName;
  final String driverPhotoUrl;
  final String startAddress;
  final GeoPoint startLocation;
  final String endAddress;
  final GeoPoint endLocation;
  final DateTime departureTime;
  final int seatsAvailable;
  final List<String> passengers;
  final List<Map<String, dynamic>> passengerRequests;
  final List<String> recurringDays;
  final List<GeoPoint> route;
  final Timestamp createdAt;
  final RideStatus status;
  final Map<String, dynamic>? passengersStatus;

  // Novo polje za bonbone i poruke
  final List<Map<String, dynamic>> candiesGifts;

  Ride({
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.driverPhotoUrl,
    required this.startAddress,
    required this.startLocation,
    required this.endAddress,
    required this.endLocation,
    required this.departureTime,
    required this.seatsAvailable,
    required this.passengers,
    required this.passengerRequests,
    required this.recurringDays,
    required this.route,
    required this.createdAt,
    this.status = RideStatus.open,
    this.passengersStatus,
    this.candiesGifts = const [],
  });

  Ride copyWith({
    String? rideId,
    String? driverId,
    String? driverName,
    String? driverPhotoUrl,
    String? startAddress,
    GeoPoint? startLocation,
    String? endAddress,
    GeoPoint? endLocation,
    DateTime? departureTime,
    int? seatsAvailable,
    List<String>? passengers,
    List<Map<String, dynamic>>? passengerRequests,
    List<String>? recurringDays,
    List<GeoPoint>? route,
    Timestamp? createdAt,
    RideStatus? status,
    Map<String, dynamic>? passengersStatus,
    List<Map<String, dynamic>>? candiesGifts,
  }) {
    return Ride(
      rideId: rideId ?? this.rideId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
      startAddress: startAddress ?? this.startAddress,
      startLocation: startLocation ?? this.startLocation,
      endAddress: endAddress ?? this.endAddress,
      endLocation: endLocation ?? this.endLocation,
      departureTime: departureTime ?? this.departureTime,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      passengers: passengers ?? this.passengers,
      passengerRequests: passengerRequests ?? this.passengerRequests,
      recurringDays: recurringDays ?? this.recurringDays,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      passengersStatus: passengersStatus ?? this.passengersStatus,
      candiesGifts: candiesGifts ?? this.candiesGifts,
    );
  }

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<Map<String, dynamic>> readCandies = [];
    if (data['candiesGifts'] != null) {
      readCandies = List<Map<String, dynamic>>.from(data['candiesGifts']);
    }

    return Ride(
      rideId: data['rideId'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      driverPhotoUrl: data['driverPhotoUrl'] ?? '',
      startAddress: data['startAddress'] ?? '',
      startLocation: data['startLocation'] ?? const GeoPoint(0, 0),
      endAddress: data['endAddress'] ?? '',
      endLocation: data['endLocation'] ?? const GeoPoint(0, 0),
      departureTime: (data['departureTime'] as Timestamp).toDate(),
      seatsAvailable: data['seatsAvailable'] ?? 0,
      passengers: List<String>.from(data['passengers'] ?? []),
      passengerRequests:
          List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []),
      recurringDays: List<String>.from(data['recurringDays'] ?? []),
      route: List<GeoPoint>.from(data['route'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      status: _statusFromString(data['status'] as String?),
      passengersStatus: data['passengersStatus'] != null
          ? Map<String, dynamic>.from(data['passengersStatus'])
          : null,
      candiesGifts: readCandies,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
      'startAddress': startAddress,
      'startLocation': startLocation,
      'endAddress': endAddress,
      'endLocation': endLocation,
      'departureTime': departureTime,
      'seatsAvailable': seatsAvailable,
      'passengers': passengers,
      'passengerRequests': passengerRequests,
      'recurringDays': recurringDays,
      'route': route,
      'createdAt': createdAt,
      'status': _statusToString(status),
      'passengersStatus': passengersStatus,
      'candiesGifts': candiesGifts,
    };
  }

  static RideStatus _statusFromString(String? statusStr) {
    switch (statusStr) {
      case 'requested':
        return RideStatus.requested;
      case 'active':
        return RideStatus.active;
      case 'completed':
        return RideStatus.completed;
      case 'canceled':
        return RideStatus.canceled;
      case 'open':
      default:
        return RideStatus.open;
    }
  }

  static String _statusToString(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'requested';
      case RideStatus.active:
        return 'active';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.canceled:
        return 'canceled';
      case RideStatus.open:
      default:
        return 'open';
    }
  }
}
