import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../local/screens/local_home_screen.dart';
import '../local/screens/post_detail_screen.dart';
import 'widgets.dart';

class LastPostsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchPosts;
  final String username;
  final bool locationAdmin;

  const LastPostsSection({
    super.key,
    required this.fetchPosts,
    required this.username,
    required this.locationAdmin,
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
            Icons.article,
            loc.translate('last_posts') ?? 'Zadnji postovi',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocalHomeScreen(
                    username: username,
                    locationAdmin: locationAdmin,
                  ),
                ),
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchPosts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 200,
                  child: buildPostsGridSkeleton(),
                );
              } else if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      loc.translate('error_loading_posts') ?? 'Error loading posts',
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      loc.translate('no_posts_available') ?? 'No posts available',
                    ),
                  ),
                );
              }
              final posts = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final String imageUrl = post['mediaUrl'] as String? ?? '';
                    final String title = post['title'] as String? ?? '';
                    final Timestamp ts = (post['createdAt'] is Timestamp)
                        ? post['createdAt'] as Timestamp
                        : Timestamp.now();
                    final DateTime createdAt = ts.toDate();
                    final String userName = post['createdBy'] as String? ?? '';
                    final String userLocation =
                        post['localNeighborhoodId'] as String? ?? '';
                    return GestureDetector(
                      onTap: () {
                        final postMap = {
                          'postId': post['postId'],
                          'userId': post['userId'] ?? '',
                          'localCountryId': post['localCountryId'] ?? '',
                          'localCityId': post['localCityId'] ?? '',
                          'localNeighborhoodId': post['localNeighborhoodId'] ?? '',
                          'isVideo': post['isVideo'] ?? false,
                          'mediaUrl': post['mediaUrl'] ?? '',
                          'aspectRatio': post['aspectRatio'] ?? 1.0,
                          'createdAt': post['createdAt'] ?? Timestamp.now(),
                          'text': post['text'] ?? '',
                          'views': post['views'] ?? 0,
                        };
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: postMap),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: buildImage(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (userName.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (userLocation.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          userLocation,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        formatTimeAgo(createdAt, loc),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
