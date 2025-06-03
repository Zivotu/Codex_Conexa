import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPost extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final String pollQuestion;
  final List<Map<String, dynamic>> pollOptions;
  final String documentId;
  final CollectionReference articlesCollection;
  final bool locationAdmin;

  const BlogPost({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.pollQuestion,
    required this.pollOptions,
    required this.documentId,
    required this.articlesCollection,
    required this.locationAdmin,
  });

  Future<bool> _hasVoted() async {
    // Implement your logic to check if the user has voted
    return false; // Placeholder implementation
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasVoted(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else {
          final hasVoted = snapshot.data ?? false;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: InkWell(
              onTap: onTap,
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/images/tenant.png',
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Colors.black54,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                  if (pollQuestion.isNotEmpty)
                    // ... (Implement poll UI)
                    const SizedBox.shrink(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up),
                        onPressed: () {
                          // Implement like functionality
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.thumb_down),
                        onPressed: () {
                          // Implement dislike functionality
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          // Implement share functionality
                        },
                      ),
                      if (locationAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: onEdit,
                        ),
                      if (locationAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
