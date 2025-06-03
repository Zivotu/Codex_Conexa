import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'package:provider/provider.dart';

class CommuteChatScreen extends StatefulWidget {
  final String rideId;
  final String userId;
  final bool isReadOnly;

  const CommuteChatScreen({
    super.key,
    required this.rideId,
    required this.userId,
    this.isReadOnly = false,
  });

  @override
  _CommuteChatScreenState createState() => _CommuteChatScreenState();
}

class _CommuteChatScreenState extends State<CommuteChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Stream<QuerySnapshot> _chatStream() {
    return FirebaseFirestore.instance
        .collection('rideshare')
        .doc(widget.rideId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('rideshare')
          .doc(widget.rideId)
          .collection('chats')
          .add({
        'senderId': widget.userId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getTranslation("error_sending_message")),
        ),
      );
    }
  }

  // Ova metoda predstavlja primjer kako dohvatiti prijevod.
  // U praksi bi mogla biti dio tvoje klase za lokalizaciju.
  String getTranslation(String key) {
    // Implementiraj dohvat prijevoda iz JSON konfiguracije ili pomoću intl paketa.
    // Ovdje samo vraćamo key za primjer.
    final translations = {
      "error_sending_message": "Error sending message!",
      "error_loading_chat": "Error loading chat",
      "loading": "Loading...",
      "unknown_user": "Unknown user",
      "enter_message": "Enter message...",
      "unknown": "Unknown",
    };
    return translations[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context, listen: false);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Text(getTranslation("loading")));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text(getTranslation("error_loading_chat")));
              }

              final messages = snapshot.data?.docs ?? [];

              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final data = msg.data() as Map<String, dynamic>;
                  final senderId = data['senderId'] ?? '';
                  final text = data['message'] ?? '';
                  final timestamp = data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now();

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: userService.getUserDocumentById(senderId),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return ListTile(
                          leading: CircleAvatar(child: Icon(Icons.person)),
                          title: Text(getTranslation("loading")),
                        );
                      }
                      if (userSnapshot.hasError || userSnapshot.data == null) {
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(getTranslation("unknown_user")),
                          subtitle: Text(text),
                          trailing: Text(DateFormat('HH:mm').format(timestamp)),
                        );
                      }
                      final userData = userSnapshot.data!;
                      final displayName =
                          userData['displayName'] ?? getTranslation("unknown");
                      final profileImageUrl = userData['profileImageUrl'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageUrl.isNotEmpty &&
                                  profileImageUrl.startsWith('http')
                              ? NetworkImage(profileImageUrl)
                              : const AssetImage(
                                  'assets/images/default_user.png',
                                ) as ImageProvider,
                        ),
                        title: Text(displayName),
                        subtitle: Text(text),
                        trailing: Text(DateFormat('HH:mm').format(timestamp)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        if (!widget.isReadOnly) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: getTranslation("enter_message"),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
