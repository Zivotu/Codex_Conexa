// lib/models/ride_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Ride {
  final String rideId;
  final String driverId;
  final GeoPoint startLocation;
  final GeoPoint endLocation;
  final String startAddress;
  final String endAddress;
  final DateTime departureTime;
  final int seatsAvailable;
  final List<String> passengers;
  final List<Map<String, dynamic>> passengerRequests;
  final Map<String, dynamic>? passengersStatus;
  final List<GeoPoint> route;
  final Timestamp createdAt;
  final List<String> recurringDays;
  final String status;
  final String driverName;
  final String driverPhotoUrl;

  Ride({
    required this.rideId,
    required this.driverId,
    required this.startLocation,
    required this.endLocation,
    required this.startAddress,
    required this.endAddress,
    required this.departureTime,
    required this.seatsAvailable,
    required this.passengers,
    required this.passengerRequests,
    required this.passengersStatus,
    required this.route,
    required this.createdAt,
    required this.recurringDays,
    required this.status,
    required this.driverName,
    required this.driverPhotoUrl,
  });

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ride(
      rideId: doc.id,
      driverId: data['driverId'] as String,
      startLocation: data['startLocation'] as GeoPoint,
      endLocation: data['endLocation'] as GeoPoint,
      startAddress: data['startAddress'] as String,
      endAddress: data['endAddress'] as String,
      departureTime: (data['departureTime'] as Timestamp).toDate(),
      seatsAvailable: data['seatsAvailable'] as int,
      passengers: List<String>.from(data['passengers'] ?? []),
      passengerRequests:
          List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []),
      passengersStatus: data['passengersStatus'] != null
          ? Map<String, dynamic>.from(data['passengersStatus'])
          : null,
      route: List<GeoPoint>.from(data['route'] ?? []),
      createdAt: data['createdAt'] as Timestamp,
      recurringDays: List<String>.from(data['recurringDays'] ?? []),
      status: data['status'] as String,
      driverName: data['driverName'] as String,
      driverPhotoUrl: data['driverPhotoUrl'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'departureTime': departureTime,
      'seatsAvailable': seatsAvailable,
      'passengers': passengers,
      'passengerRequests': passengerRequests,
      'passengersStatus': passengersStatus,
      'route': route,
      'createdAt': createdAt,
      'recurringDays': recurringDays,
      'status': status,
      'driverName': driverName,
      'driverPhotoUrl': driverPhotoUrl,
    };
  }

  Ride copyWith({
    String? rideId,
    String? driverId,
    GeoPoint? startLocation,
    GeoPoint? endLocation,
    String? startAddress,
    String? endAddress,
    DateTime? departureTime,
    int? seatsAvailable,
    List<String>? passengers,
    List<Map<String, dynamic>>? passengerRequests,
    Map<String, dynamic>? passengersStatus,
    List<GeoPoint>? route,
    Timestamp? createdAt,
    List<String>? recurringDays,
    String? status,
    String? driverName,
    String? driverPhotoUrl,
  }) {
    return Ride(
      rideId: rideId ?? this.rideId,
      driverId: driverId ?? this.driverId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      departureTime: departureTime ?? this.departureTime,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      passengers: passengers ?? this.passengers,
      passengerRequests: passengerRequests ?? this.passengerRequests,
      passengersStatus: passengersStatus ?? this.passengersStatus,
      route: route ?? this.route,
      createdAt: createdAt ?? this.createdAt,
      recurringDays: recurringDays ?? this.recurringDays,
      status: status ?? this.status,
      driverName: driverName ?? this.driverName,
      driverPhotoUrl: driverPhotoUrl ?? this.driverPhotoUrl,
    );
  }
}
