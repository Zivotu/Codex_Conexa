import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'full_screen_image.dart';
import 'package:logger/logger.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageWidget extends StatefulWidget {
  final DocumentSnapshot chat;
  final bool isMe;
  final String? localImagePath;
  final Function(DocumentSnapshot) onLike;
  final Function(DocumentSnapshot) onDislike;
  final Function(DocumentSnapshot) onShare;
  final Function(DocumentSnapshot) onReply;

  const MessageWidget({
    super.key,
    required this.chat,
    required this.isMe,
    required this.localImagePath,
    required this.onLike,
    required this.onDislike,
    required this.onShare,
    required this.onReply,
  });

  @override
  MessageWidgetState createState() => MessageWidgetState();
}

class MessageWidgetState extends State<MessageWidget> {
  late String profileImageUrl;
  late String username;
  late String locationName;
  late String cityName;
  late String countryName;
  final Logger _logger = Logger();
  bool _hasViewed = false;

  @override
  void initState() {
    super.initState();
    profileImageUrl = 'assets/images/default_user.png';
    username = 'Nepoznati korisnik';
    locationName = 'Nepoznata lokacija';
    cityName = 'Nepoznati grad';
    countryName = 'Nepoznata država';

    _getUserAndLocationData();
    _checkIfViewed();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    return DateFormat('dd.MM.yyyy - HH:mm - EEEE', 'hr_HR').format(date);
  }

  /// Pomoćna funkcija koja vraća string s prvim slovom kapitaliziranim
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _getUserAndLocationData() async {
    // Dohvati podatke o korisniku iz kolekcije "users" koristeći userId iz poruke
    final userId = widget.chat.get('userId');
    if (userId != null && userId.toString().isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            // Koristi polje "username" umjesto "displayName"
            username = userData?['username'] ?? 'Nepoznati korisnik';
            profileImageUrl =
                (userData?['profileImageUrl'] as String?)?.trim() ??
                    'assets/images/default_user.png';
          });
        } else {
          _logger.w('Korisnički dokument nije pronađen za userId: $userId');
        }
      } catch (e) {
        _logger.e('Greška pri dohvaćanju korisničkih podataka: $e');
      }
    }

    // Dohvati lokacijske podatke (ako su potrebni)
    final locationId = widget.chat.get('locationId');
    if (locationId != null && locationId.toString().isNotEmpty) {
      try {
        final locationDoc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locationId)
            .get();

        if (locationDoc.exists) {
          setState(() {
            locationName = locationDoc.data()?['name'] ?? 'Nepoznata lokacija';
          });
        } else {
          _logger.w(
              'Lokacijski dokument nije pronađen za locationId: $locationId');
        }
      } catch (e) {
        _logger.e('Greška pri dohvaćanju lokacijskih podataka: $e');
      }
    }
    // Ako su potrebni podaci za grad i državu, dodajte ih ovdje
  }

  Future<void> _checkIfViewed() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final viewedBy = List<String>.from(widget.chat.get('viewedBy') ?? []);
    if (!viewedBy.contains(userId)) {
      await FirebaseFirestore.instance
          .collection('messages') // Zamijenite naziv kolekcije ako je drugačiji
          .doc(widget.chat.id)
          .update({
        'viewedBy': FieldValue.arrayUnion([userId])
      });
      setState(() {
        _hasViewed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.chat.data() as Map<String, dynamic>?;

    return VisibilityDetector(
      key: Key(widget.chat.id),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.1 && !_hasViewed) {
          _checkIfViewed();
        }
      },
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: widget.isMe
                ? _buildMessageContentForMe(data)
                : _buildMessageContentForOthers(data),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessageContentForMe(Map<String, dynamic>? data) {
    // Poruka trenutnog korisnika: sadržaj desno
    return [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _buildMessageColumnChildren(data),
        ),
      ),
      const SizedBox(width: 10),
      CircleAvatar(
        backgroundImage: profileImageUrl.isNotEmpty
            ? (profileImageUrl.startsWith('http')
                ? NetworkImage(profileImageUrl)
                : AssetImage(profileImageUrl) as ImageProvider)
            : const AssetImage('assets/images/default_user.png'),
        onBackgroundImageError: (_, __) {
          setState(() {
            profileImageUrl = 'assets/images/default_user.png';
          });
        },
      ),
    ];
  }

  List<Widget> _buildMessageContentForOthers(Map<String, dynamic>? data) {
    // Poruka drugih korisnika: sadržaj lijevo
    return [
      CircleAvatar(
        backgroundImage: profileImageUrl.isNotEmpty
            ? (profileImageUrl.startsWith('http')
                ? NetworkImage(profileImageUrl)
                : AssetImage(profileImageUrl) as ImageProvider)
            : const AssetImage('assets/images/default_user.png'),
        onBackgroundImageError: (_, __) {
          setState(() {
            profileImageUrl = 'assets/images/default_user.png';
          });
        },
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildMessageColumnChildren(data),
        ),
      ),
    ];
  }

  List<Widget> _buildMessageColumnChildren(Map<String, dynamic>? data) {
    return [
      Text(
        username,
        style: const TextStyle(
          color: Color(0xFF637588),
          fontSize: 13,
        ),
      ),
      Text(
        '$locationName, $cityName, $countryName',
        style: const TextStyle(
          color: Color(0xFF9B9B9B),
          fontSize: 12,
        ),
      ),
      if (data != null &&
          data['imageUrl'] != null &&
          data['imageUrl'].toString().isNotEmpty)
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FullScreenImage(imageUrl: data['imageUrl']),
              ),
            );
          },
          child: Image.network(data['imageUrl'],
              errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          }),
        ),
      if (data != null &&
          data['text'] != null &&
          data['text'].toString().isNotEmpty)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F4),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Text(
            _capitalize(data['text']),
            style: const TextStyle(
              color: Color(0xFF111418),
              fontSize: 16,
            ),
          ),
        ),
      Align(
        alignment: Alignment.bottomRight,
        child: Text(
          _formatTimestamp(data?['createdAt'] ?? Timestamp.now()),
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility,
              size: 16,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              '${data?['viewedBy']?.length ?? 0}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.bottomRight,
        child: Wrap(
          spacing: 8,
          children: [
            IconButton(
              icon: Icon(
                data?['likedBy']?.contains(
                            FirebaseAuth.instance.currentUser?.uid) ??
                        false
                    ? Icons.thumb_up
                    : Icons.thumb_up_off_alt,
                color: data?['likedBy']?.contains(
                            FirebaseAuth.instance.currentUser?.uid) ??
                        false
                    ? Colors.blue
                    : Colors.black,
              ),
              onPressed: () => widget.onLike(widget.chat),
            ),
            Text('${data?['likes'] ?? 0}'),
            IconButton(
              icon: Icon(
                data?['dislikedBy']?.contains(
                            FirebaseAuth.instance.currentUser?.uid) ??
                        false
                    ? Icons.thumb_down
                    : Icons.thumb_down_off_alt,
                color: data?['dislikedBy']?.contains(
                            FirebaseAuth.instance.currentUser?.uid) ??
                        false
                    ? Colors.red
                    : Colors.black,
              ),
              onPressed: () => widget.onDislike(widget.chat),
            ),
            Text('${data?['dislikes'] ?? 0}'),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.black),
              onPressed: () => widget.onShare(widget.chat),
            ),
            Text('${data?['shares'] ?? 0}'),
            IconButton(
              icon: const Icon(Icons.reply, color: Colors.black),
              onPressed: () => widget.onReply(widget.chat),
            ),
          ],
        ),
      ),
    ];
  }
}
