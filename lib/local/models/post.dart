import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  String postId;
  final String userId;
  final int userAge;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likes;
  final int dislikes;
  final int shares;
  final int reports;
  final String text;
  final String subject;
  final int views;
  final String country;
  final String city;
  final String neighborhood;
  final String localCountryId;
  final String localCityId;
  final String localNeighborhoodId;
  final bool isAnonymous;
  final String username; // Dodano ranije
  final String deviceIdentifier;
  final GeoPoint userGeoLocation;
  final GeoPoint postGeoLocation;
  final String location;
  final String address;
  final String? mediaUrl;
  final double aspectRatio;
  final String orientation;

  // NOVA POLJA
  final bool isInternal; // ← novo
  final String? locationId; // ← novo

  final String year;
  final String month;
  final String day;

  Post({
    required this.postId,
    required this.userId,
    required this.userAge,
    required this.createdAt,
    required this.updatedAt,
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.reports,
    required this.text,
    required this.subject,
    required this.views,
    required this.country,
    required this.city,
    required this.neighborhood,
    required this.localCountryId,
    required this.localCityId,
    required this.localNeighborhoodId,
    required this.isAnonymous,
    required this.username,
    required this.deviceIdentifier,
    required this.userGeoLocation,
    required this.postGeoLocation,
    required this.location,
    required this.address,
    this.mediaUrl,
    required this.aspectRatio,
    required this.orientation,
    /* nova parametra – nisu obavezna */
    this.isInternal = false,
    this.locationId,
  })  : year = createdAt.year.toString(),
        month = createdAt.month.toString().padLeft(2, '0'),
        day = createdAt.day.toString().padLeft(2, '0');

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      postId: doc.id,
      userId: data['userId'] ?? '',
      userAge: data['userAge'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      dislikes: data['dislikes'] ?? 0,
      shares: data['shares'] ?? 0,
      reports: data['reports'] ?? 0,
      text: data['text'] ?? '',
      subject: data['subject'] ?? '',
      views: data['views'] ?? 0,
      country: data['country'] ?? '',
      city: data['city'] ?? '',
      neighborhood: data['neighborhood'] ?? '',
      localCountryId: data['localCountryId'] ?? '',
      localCityId: data['localCityId'] ?? '',
      localNeighborhoodId: data['localNeighborhoodId'] ?? '',
      isAnonymous: data['isAnonymous'] ?? false,
      username: data['username'] ?? 'Korisnik',
      deviceIdentifier: data['deviceIdentifier'] ?? '',
      userGeoLocation: data['userGeoLocation'] as GeoPoint,
      postGeoLocation: data['postGeoLocation'] as GeoPoint,
      location: data['location'] ?? '',
      address: data['address'] ?? '',
      mediaUrl: data['mediaUrl'],
      aspectRatio: data['aspectRatio'] ?? 1.0,
      orientation: data['orientation'] ?? 'unknown',
      // nova polja
      isInternal: data['isInternal'] ?? false,
      locationId: data['locationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userAge': userAge,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'likes': likes,
      'dislikes': dislikes,
      'shares': shares,
      'reports': reports,
      'text': text,
      'subject': subject,
      'views': views,
      'country': country,
      'city': city,
      'neighborhood': neighborhood,
      'localCountryId': localCountryId,
      'localCityId': localCityId,
      'localNeighborhoodId': localNeighborhoodId,
      'isAnonymous': isAnonymous,
      'username': username,
      'deviceIdentifier': deviceIdentifier,
      'userGeoLocation': userGeoLocation,
      'postGeoLocation': postGeoLocation,
      'location': location,
      'address': address,
      'mediaUrl': mediaUrl,
      'aspectRatio': aspectRatio,
      'orientation': orientation,
      // nova polja
      'isInternal': isInternal,
      'locationId': locationId,
      'year': year,
      'month': month,
      'day': day,
    };
  }
}
