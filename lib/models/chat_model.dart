// lib/models/chat_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  String id;
  String text;
  String imageUrl;
  Timestamp createdAt;
  String user; // Koristi displayName
  String userId;
  String profileImageUrl; // Dosljedno ime polja
  int likes;
  int dislikes;
  int shares;
  List<String> viewedBy;
  List<String> likedBy;
  List<String> dislikedBy;
  String? repliesTo;

  ChatModel({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.user, // displayName
    required this.userId,
    required this.profileImageUrl,
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.viewedBy,
    required this.likedBy,
    required this.dislikedBy,
    this.repliesTo,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      createdAt: json['createdAt'] as Timestamp,
      user: json['user'] as String? ?? 'Nepoznati korisnik', // displayName
      userId: json['userId'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
      likes: json['likes'] as int? ?? 0,
      dislikes: json['dislikes'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      viewedBy: List<String>.from(json['viewedBy'] ?? []),
      likedBy: List<String>.from(json['likedBy'] ?? []),
      dislikedBy: List<String>.from(json['dislikedBy'] ?? []),
      repliesTo: json['repliesTo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'user': user, // displayName
      'userId': userId,
      'profileImageUrl': profileImageUrl,
      'likes': likes,
      'dislikes': dislikes,
      'shares': shares,
      'viewedBy': viewedBy,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'repliesTo': repliesTo,
    };
  }
}
