import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  String text;
  String imageUrl;
  Timestamp createdAt;
  String user;
  String userId;

  MessageModel({
    this.text = '',
    this.imageUrl = '',
    required this.createdAt,
    this.user = 'Unknown User',
    this.userId = 'defaultUserId',
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'user': user,
      'userId': userId,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      text: json['text'],
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'],
      user: json['user'],
      userId: json['userId'],
    );
  }
}
