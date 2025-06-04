import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/chat_model.dart';
import '../../services/localization_service.dart';
import '../group_chat_page.dart';
import 'widgets.dart';

class ChatRoomSection extends StatelessWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String geoCountry;
  final String geoCity;
  final String geoNeighborhood;
  final FirebaseFirestore firestore;

  const ChatRoomSection({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.geoCountry,
    required this.geoCity,
    required this.geoNeighborhood,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          buildSectionHeader(
            Icons.chat,
            loc.translate('chat') ?? 'Chat',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatPage(
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          FutureBuilder<QuerySnapshot>(
            future: firestore
                .collection('countries')
                .doc(geoCountry.isNotEmpty ? geoCountry : countryId)
                .collection('cities')
                .doc(geoCity.isNotEmpty ? geoCity : cityId)
                .collection('locations')
                .doc(geoNeighborhood.isNotEmpty ? geoNeighborhood : locationId)
                .collection('chats')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('error_loading_chats') ?? 'Error loading chats.',
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('no_chat_messages_available') ??
                          'No chat messages available.',
                    ),
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              final List<ChatModel> lastMessages = docs
                  .map((doc) => ChatModel.fromJson(doc.data() as Map<String, dynamic>))
                  .toList();
              return Column(
                children:
                    lastMessages.map((chat) => _SingleChatMessage(chat: chat, loc: loc, countryId: countryId, cityId: cityId, locationId: locationId)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SingleChatMessage extends StatelessWidget {
  final ChatModel chat;
  final LocalizationService loc;
  final String countryId;
  final String cityId;
  final String locationId;

  const _SingleChatMessage({
    required this.chat,
    required this.loc,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  Widget build(BuildContext context) {
    final String profileImg = chat.profileImageUrl.isNotEmpty
        ? chat.profileImageUrl
        : 'assets/images/default_user.png';
    final String messageText = chat.text;
    final DateTime timeSent = chat.createdAt.toDate();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatPage(
              countryId: countryId,
              cityId: cityId,
              locationId: locationId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(child: buildImage(profileImg, width: 40, height: 40)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.user.isNotEmpty ? chat.user : 'Unknown User',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (messageText.isNotEmpty)
                      Text(messageText, style: const TextStyle(fontSize: 14)),
                    if (chat.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: chat.imageUrl,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formatTimeAgo(timeSent, loc),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
