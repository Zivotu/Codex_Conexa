import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Dodano za debugPrint

class Bulletin {
  String id;
  String title;
  String description;
  List<String> imagePaths;
  int likes;
  int dislikes;
  bool userLiked;
  bool userDisliked;
  DateTime createdAt;
  List<Map<String, dynamic>> comments;
  String createdBy;
  GeoPoint location;
  double radius; // 1.0, 5.0, 15.0 km
  bool isInternal; // True za interne oglase
  bool expired; // True ako je oglas istekao

  Bulletin({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePaths,
    required this.likes,
    required this.dislikes,
    this.userLiked = false,
    this.userDisliked = false,
    required this.createdAt,
    this.comments = const [],
    required this.createdBy,
    required this.location,
    required this.radius,
    this.isInternal = false,
    this.expired = false,
  });

  factory Bulletin.fromJson(Map<String, dynamic> json) {
    GeoPoint location;
    if (json.containsKey('location') && json['location'] is GeoPoint) {
      location = json['location'];
    } else if (json.containsKey('latitude') && json.containsKey('longitude')) {
      final latitude = json['latitude'];
      final longitude = json['longitude'];
      if (latitude is num && longitude is num) {
        location = GeoPoint(latitude.toDouble(), longitude.toDouble());
      } else {
        debugPrint('Polja "latitude" ili "longitude" nisu ispravnog tipa.');
        location = const GeoPoint(0.0, 0.0);
      }
    } else {
      // Ako nema podatka, vraćamo defaultnu vrijednost
      location = const GeoPoint(0.0, 0.0);
    }

    return Bulletin(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imagePaths: (json['imagePaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      likes: json['likes'],
      dislikes: json['dislikes'],
      userLiked: json['userLiked'] ?? false,
      userDisliked: json['userDisliked'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      createdBy: json['createdBy'],
      location: location,
      radius: (json['radius'] as num).toDouble(),
      isInternal: json['isInternal'] ?? false,
      expired: json['expired'] ?? false,
    );
  }

  // Dodana metoda fromMap koja postavlja id te poziva fromJson
  factory Bulletin.fromMap(Map<String, dynamic> map, String id) {
    map['id'] = id;
    return Bulletin.fromJson(map);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePaths': imagePaths,
      'likes': likes,
      'dislikes': dislikes,
      'userLiked': userLiked,
      'userDisliked': userDisliked,
      'createdAt': createdAt,
      'comments': comments,
      'createdBy': createdBy,
      'location': location,
      'radius': radius,
      'isInternal': isInternal,
      'expired': expired,
    };
  }
}
