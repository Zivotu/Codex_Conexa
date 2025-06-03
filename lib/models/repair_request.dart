import 'package:cloud_firestore/cloud_firestore.dart';
import 'time_frame.dart';
import 'servicer_offer.dart';
import 'package:geolocator/geolocator.dart';

class RepairRequest {
  final String id;
  final String reportNumber;
  final String issueType;
  final DateTime requestedDate;
  final DateTime? expirationDate;
  final String description;
  final String notes;
  final List<String> imagePaths;
  final String? videoPath;
  final String userId;
  final DateTime? agreedDate; // Dodano polje
  final DateTime? completedDate; // Dodano polje
  final String? userName;
  final String? userAddress;
  final String status;
  final bool isCancelled;
  final bool isModified;
  final List<TimeFrame> timeFrames;
  final List<Timestamp?> offeredTimeSlots;
  final Timestamp? selectedTimeSlot;
  final Timestamp? servicerConfirmedTimeSlot;
  final Timestamp? timeOfSelectedTimeSlot;
  final double? userLatitude;
  final double? userLongitude;
  final String? servicerId;
  final String? fcmToken;
  final String? servicerFcmToken;
  final String? countryId;
  final String? cityId;
  final String? locationId;
  final String? address;
  final String? naselje;
  final List<ServicerOffer> servicerOffers;
  final List<String> servicerIds;
  final int? durationDays;
  final DocumentReference? reference;
  final bool notificationSeen;

  RepairRequest({
    required this.id,
    required this.reportNumber,
    required this.issueType,
    required this.requestedDate,
    this.expirationDate,
    required this.description,
    this.agreedDate, // Dodano u konstruktor
    this.completedDate, // Dodano u konstruktor
    required this.notes,
    required this.imagePaths,
    this.videoPath,
    required this.userId,
    this.userName,
    this.userAddress,
    required this.status,
    this.isCancelled = false,
    this.isModified = false,
    required this.timeFrames,
    required this.offeredTimeSlots,
    this.selectedTimeSlot,
    this.servicerConfirmedTimeSlot,
    this.timeOfSelectedTimeSlot,
    this.userLatitude,
    this.userLongitude,
    this.servicerId,
    this.fcmToken,
    this.servicerFcmToken,
    this.countryId,
    this.cityId,
    this.locationId,
    this.address,
    this.naselje,
    this.servicerOffers = const [],
    this.servicerIds = const [],
    this.durationDays,
    this.reference,
    this.notificationSeen = false,
  });

  /// Metoda za kloniranje instance sa promjenom željenih vrijednosti.
  RepairRequest copyWith({
    String? status,
    DateTime? agreedDate,
    DateTime? completedDate,
    Timestamp? selectedTimeSlot,
    Timestamp? servicerConfirmedTimeSlot,
    String? servicerId,
    bool? isCancelled,
    bool? isModified,
    List<Timestamp?>? offeredTimeSlots,
    List<ServicerOffer>? servicerOffers,
    bool? notificationSeen,
  }) {
    return RepairRequest(
      id: id,
      reportNumber: reportNumber,
      issueType: issueType,
      requestedDate: requestedDate,
      expirationDate: expirationDate,
      description: description,
      agreedDate: agreedDate ?? this.agreedDate,
      completedDate: completedDate ?? this.completedDate,
      notes: notes,
      imagePaths: imagePaths,
      videoPath: videoPath,
      userId: userId,
      userName: userName,
      userAddress: userAddress,
      status: status ?? this.status,
      isCancelled: isCancelled ?? this.isCancelled,
      isModified: isModified ?? this.isModified,
      timeFrames: timeFrames,
      offeredTimeSlots: offeredTimeSlots ?? this.offeredTimeSlots,
      selectedTimeSlot: selectedTimeSlot ?? this.selectedTimeSlot,
      servicerConfirmedTimeSlot:
          servicerConfirmedTimeSlot ?? this.servicerConfirmedTimeSlot,
      timeOfSelectedTimeSlot: timeOfSelectedTimeSlot,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      servicerId: servicerId ?? this.servicerId,
      fcmToken: fcmToken,
      servicerFcmToken: servicerFcmToken,
      countryId: countryId,
      cityId: cityId,
      locationId: locationId,
      address: address,
      naselje: naselje,
      servicerOffers: servicerOffers ?? this.servicerOffers,
      servicerIds: servicerIds,
      durationDays: durationDays,
      reference: reference,
      notificationSeen: notificationSeen ?? this.notificationSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'issueType': issueType,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'expirationDate':
          expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      'description': description,
      'notes': notes,
      'imagePaths': imagePaths,
      'videoPath': videoPath,
      'userId': userId,
      'userName': userName,
      'userAddress': userAddress,
      'status': status,
      'isCancelled': isCancelled,
      'isModified': isModified,
      'timeFrames': timeFrames.map((tf) => tf.toMap()).toList(),
      'offeredTimeSlots': offeredTimeSlots,
      'selectedTimeSlot': selectedTimeSlot,
      'servicerConfirmedTimeSlot': servicerConfirmedTimeSlot,
      'timeOfSelectedTimeSlot': timeOfSelectedTimeSlot,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'servicerId': servicerId,
      'fcmToken': fcmToken,
      'servicerFcmToken': servicerFcmToken,
      'countryId': countryId,
      'cityId': cityId,
      'locationId': locationId,
      'address': address,
      'naselje': naselje,
      'agreedDate': agreedDate != null ? Timestamp.fromDate(agreedDate!) : null,
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'servicerOffers': servicerOffers.map((offer) => offer.toMap()).toList(),
      'servicerIds': servicerIds,
      'durationDays': durationDays,
      'notificationSeen': notificationSeen,
    };
  }

  factory RepairRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RepairRequest.fromMap(data, reference: doc.reference);
  }

  factory RepairRequest.fromMap(Map<String, dynamic> data,
      {DocumentReference? reference}) {
    return RepairRequest(
      id: data['id'] ?? '',
      reportNumber: data['reportNumber'] ?? '',
      issueType: data['issueType'] ?? '',
      requestedDate: (data['requestedDate'] as Timestamp).toDate(),
      expirationDate: data['expirationDate'] != null
          ? (data['expirationDate'] as Timestamp).toDate()
          : null,
      description: data['description'] ?? '',
      notes: data['notes'] ?? '',
      imagePaths: List<String>.from(data['imagePaths'] ?? []),
      videoPath: data['videoPath'],
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userAddress: data['userAddress'],
      status: data['status'] ?? '',
      isCancelled: data['isCancelled'] ?? false,
      isModified: data['isModified'] ?? false,
      timeFrames: data['timeFrames'] != null
          ? List<TimeFrame>.from(
              data['timeFrames'].map((item) => TimeFrame.fromMap(item)),
            )
          : [],
      offeredTimeSlots: data['offeredTimeSlots'] != null
          ? List<Timestamp?>.from(data['offeredTimeSlots'])
          : [],
      selectedTimeSlot: data['selectedTimeSlot'],
      servicerConfirmedTimeSlot: data['servicerConfirmedTimeSlot'],
      timeOfSelectedTimeSlot: data['timeOfSelectedTimeSlot'],
      userLatitude: data['userLatitude']?.toDouble(),
      userLongitude: data['userLongitude']?.toDouble(),
      servicerId: data['servicerId'],
      fcmToken: data['fcmToken'],
      servicerFcmToken: data['servicerFcmToken'],
      countryId: data['countryId'],
      cityId: data['cityId'],
      locationId: data['locationId'],
      address: data['address'],
      naselje: data['naselje'],
      agreedDate: data['agreedDate'] != null
          ? (data['agreedDate'] as Timestamp).toDate()
          : null,
      completedDate: data['completedDate'] != null
          ? (data['completedDate'] as Timestamp).toDate()
          : null,
      servicerOffers: data['servicerOffers'] != null
          ? List<ServicerOffer>.from(
              data['servicerOffers']
                  .map((offerData) => ServicerOffer.fromMap(offerData)),
            )
          : [],
      servicerIds: data['servicerIds'] != null
          ? List<String>.from(data['servicerIds'])
          : [],
      durationDays: data['durationDays'],
      reference: reference,
      notificationSeen: data['notificationSeen'] ?? false,
    );
  }

  int get totalOffers => servicerOffers.length;

  DateTime? get calculatedExpirationDate =>
      expirationDate ?? requestedDate.add(const Duration(days: 7));

  bool isWithinTimeFrames(DateTime dateTime) {
    for (var timeFrame in timeFrames) {
      if (timeFrame.isWithinTimeFrame(dateTime)) {
        return true;
      }
    }
    return false;
  }

  double calculateDistance(double servicerLatitude, double servicerLongitude) {
    if (userLatitude != null && userLongitude != null) {
      return Geolocator.distanceBetween(
            userLatitude!,
            userLongitude!,
            servicerLatitude,
            servicerLongitude,
          ) /
          1000; // Convert to kilometers
    }
    return double.infinity;
  }
}
