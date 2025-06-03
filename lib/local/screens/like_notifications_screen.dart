import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:conexa/services/localization_service.dart'; // Import za lokalizaciju
import 'package:provider/provider.dart'; // Za pristup LocalizationService

class LikeNotificationsScreen extends StatefulWidget {
  const LikeNotificationsScreen({super.key});

  @override
  LikeNotificationsScreenState createState() => LikeNotificationsScreenState();
}

class LikeNotificationsScreenState extends State<LikeNotificationsScreen> {
  List<Map<String, dynamic>> _likedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getLikedPosts();
  }

  Future<void> _getLikedPosts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      QuerySnapshot userPostsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .orderBy('createdAt', descending: true) // Prikazujemo sve postove
          .get();

      List<Map<String, dynamic>> likedPosts = [];

      for (var postDoc in userPostsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;

        likedPosts.add({
          ...postData,
          'postId': postDoc.id,
          'likes': postData['likes'] ?? 0,
          'views': postData['views'] ?? 0,
        });
      }

      setState(() {
        _likedPosts = likedPosts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching liked posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('your_posts_with_likes_and_views')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _likedPosts.isEmpty
              ? Center(
                  child: Text(localization.translate('no_posts_available')),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _likedPosts.length,
                  itemBuilder: (context, index) {
                    final post = _likedPosts[index];
                    final imageUrl = post['mediaUrl'] ?? '';
                    final likeCount = post['likes'] ?? 0;
                    final viewCount = post['views'] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 3,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            localization.translate(
                                                'image_not_available'),
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 16),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        localization.translate('no_image'),
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 16),
                                      ),
                                    ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.black87,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.thumb_up,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$likeCount',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.visibility,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$viewCount',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
