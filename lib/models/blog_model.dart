import 'package:cloud_firestore/cloud_firestore.dart'; // Ensure Firestore Timestamp is imported

class Blog {
  String id;
  String title;
  String content;
  DateTime createdAt;
  final String author;
  final String createdBy; // Dodano polje za ID korisnika
  List<String> imageUrls; // Polje za više slika
  String pollQuestion;
  List<Map<String, dynamic>> pollOptions;
  List<String> votedUsers;
  int likes;
  int dislikes;
  int shares; // Polje za broj dijeljenja
  List<String> likedUsers;
  List<String> dislikedUsers;

  Blog({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.author,
    required this.createdBy, // Dodano u konstruktor
    this.imageUrls = const [], // Inicijalizirano s praznim popisom
    required this.pollQuestion,
    required this.pollOptions,
    required this.votedUsers,
    this.likes = 0,
    this.dislikes = 0,
    this.shares = 0, // Inicijalizirano
    this.likedUsers = const [],
    this.dislikedUsers = const [],
  });

  // Factory metoda za kreiranje Blog instance iz Firestore podataka
  factory Blog.fromMap(Map<String, dynamic> map, String id) {
    return Blog(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      author: map['author'] ?? '',
      createdBy: map['createdBy'] ?? '', // Mapiranje polja createdBy
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      pollQuestion: map['pollQuestion'] ?? '',
      pollOptions: List<Map<String, dynamic>>.from(map['pollOptions'] ?? []),
      votedUsers: List<String>.from(map['votedUsers'] ?? []),
      likes: map['likes'] ?? 0,
      dislikes: map['dislikes'] ?? 0,
      shares: map['shares'] ?? 0,
      likedUsers: List<String>.from(map['likedUsers'] ?? []),
      dislikedUsers: List<String>.from(map['dislikedUsers'] ?? []),
    );
  }

  // Metoda za pretvaranje Blog instance u Firestore-friendly mapu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'author': author,
      'createdBy': createdBy, // Dodavanje polja createdBy
      'imageUrls': imageUrls, // Uključivanje polja imageUrls u mapu
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'votedUsers': votedUsers,
      'likes': likes,
      'dislikes': dislikes,
      'shares': shares,
      'likedUsers': likedUsers,
      'dislikedUsers': dislikedUsers,
    };
  }
}
