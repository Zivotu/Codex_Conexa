// lib/local/screens/post_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_detail_screen.dart';
import 'package:conexa/services/localization_service.dart'; // Import za lokalizaciju

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isGridView;

  const PostWidget({
    super.key,
    required this.postData,
    this.isGridView = false,
  });

  @override
  PostWidgetState createState() => PostWidgetState();
}

class PostWidgetState extends State<PostWidget> {
  final Logger _logger = Logger('PostWidgetLogger');

  int likes = 0;
  int dislikes = 0;
  int shares = 0;
  int views = 0;

  bool hasLiked = false;
  bool hasDisliked = false;
  String? username;

  @override
  void initState() {
    super.initState();
    _loadMetricsFromFirestore();
    _checkUserInteraction();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    try {
      if (widget.postData['isAnonymous'] == true) {
        setState(() {
          username = LocalizationService.instance.translate('anonymous');
        });
      } else if (widget.postData.containsKey('username')) {
        setState(() {
          username = widget.postData['username'];
        });
      } else {
        final userId = widget.postData['userId'];
        if (userId != null && userId.isNotEmpty) {
          DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userSnapshot.exists) {
            final userData = userSnapshot.data() as Map<String, dynamic>;
            setState(() {
              username = userData['username'] ??
                  LocalizationService.instance.translate('unknown_user');
            });
          }
        }
      }
    } catch (e) {
      _logger.severe('Greška prilikom učitavanja korisničkog imena: $e');
    }
  }

  Future<void> _loadMetricsFromFirestore() async {
    try {
      final postId = widget.postData['postId'] ?? widget.postData['id'];
      if (postId == null || postId.isEmpty) {
        _logger.severe("Post ID je null ili prazan. Ne mogu nastaviti.");
        return;
      }

      final country = widget.postData['localCountryId'];
      final city = widget.postData['localCityId'];
      final neighborhood = widget.postData['localNeighborhoodId'];

      final metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      DocumentSnapshot metricsSnapshot =
          await FirebaseFirestore.instance.doc(metricsPath).get();

      if (metricsSnapshot.exists) {
        final data = metricsSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            likes = data['likes'] ?? 0;
            dislikes = data['dislikes'] ?? 0;
            shares = data['shares'] ?? 0;
            views = data['views'] ?? 0;
          });
        }
      } else {
        _logger.warning("Nisu pronađene metrike za postId: $postId");
      }
    } catch (e) {
      _logger.severe('Greška prilikom učitavanja metrika: $e');
    }
  }

  Future<void> _checkUserInteraction() async {
    try {
      final postId = widget.postData['postId'] ?? widget.postData['id'];
      if (postId == null || postId.isEmpty) {
        _logger.severe("Post ID je null ili prazan. Ne mogu nastaviti.");
        return;
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        return;
      }

      final userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      DocumentSnapshot interactionSnapshot = await userInteractionDoc.get();

      if (interactionSnapshot.exists) {
        final data = interactionSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            hasLiked = data['hasLiked'] ?? false;
            hasDisliked = data['hasDisliked'] ?? false;
          });
        }
      }
    } catch (e) {
      _logger.severe('Greška prilikom provjere interakcije korisnika: $e');
    }
  }

  Future<void> _handleLike() async {
    final postId = widget.postData['postId'] ?? widget.postData['id'];
    if (postId == null || postId.isEmpty) {
      _logger.severe("Post ID je null ili prazan. Ne mogu nastaviti.");
      return;
    }

    if (hasLiked || hasDisliked) {
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _showError(LocalizationService.instance.translate('like_error'));
        return;
      }

      final country = widget.postData['localCountryId'];
      final city = widget.postData['localCityId'];
      final neighborhood = widget.postData['localNeighborhoodId'];

      setState(() {
        likes++;
        hasLiked = true;
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final postPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final communityMetricsRef = FirebaseFirestore.instance.doc(metricsPath);
      final postRef = FirebaseFirestore.instance.doc(postPath);

      batch.set(
        communityMetricsRef,
        {'likes': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      batch.set(
        postRef,
        {
          'likes': FieldValue.increment(1),
          'lastLikedAt': FieldValue.serverTimestamp()
        },
        SetOptions(merge: true),
      );

      final userPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postData['userId'])
          .collection('userPosts')
          .doc(postId);

      batch.update(userPostRef, {'likes': FieldValue.increment(1)});

      final userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      batch.set(userInteractionDoc, {
        'hasLiked': true,
        'hasDisliked': false,
      });

      await batch.commit();
      _loadMetricsFromFirestore();
    } catch (e) {
      setState(() {
        likes--;
      });
      _logger.severe('Greška prilikom lajkanja: $e');
    }
  }

  Future<void> _handleDislike() async {
    final postId = widget.postData['postId'] ?? widget.postData['id'];
    if (postId == null || postId.isEmpty) {
      _logger.severe("Post ID je null ili prazan. Ne mogu nastaviti.");
      return;
    }

    if (hasLiked || hasDisliked) {
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        _showError(LocalizationService.instance.translate('dislike_error'));
        return;
      }

      final country = widget.postData['localCountryId'];
      final city = widget.postData['localCityId'];
      final neighborhood = widget.postData['localNeighborhoodId'];

      setState(() {
        dislikes++;
        hasDisliked = true;
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final postPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final communityMetricsRef = FirebaseFirestore.instance.doc(metricsPath);
      final postRef = FirebaseFirestore.instance.doc(postPath);

      batch.set(
        communityMetricsRef,
        {'dislikes': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      batch.set(
        postRef,
        {'dislikes': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      final userPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postData['userId'])
          .collection('userPosts')
          .doc(postId);

      batch.update(userPostRef, {'dislikes': FieldValue.increment(1)});

      final userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      batch.set(userInteractionDoc, {
        'hasLiked': false,
        'hasDisliked': true,
      });

      await batch.commit();
      _loadMetricsFromFirestore();
    } catch (e) {
      setState(() {
        dislikes--;
      });
      _logger.severe('Greška prilikom dislajkanja: $e');
    }
  }

  Widget _buildViewIconWithNumber(int views) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(
          Icons.visibility,
          color: Colors.white.withOpacity(0.8),
          size: widget.isGridView ? 16.0 : 24.0,
          shadows: [
            Shadow(
              blurRadius: 4.0,
              color: Colors.black.withOpacity(0.7),
              offset: const Offset(2.0, 2.0),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$views',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: widget.isGridView ? 10.0 : 12.0,
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Widget _buildIconButton(
      IconData icon, int count, VoidCallback? onPressed, double iconSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
          iconSize: iconSize,
          onPressed: onPressed,
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        Transform.translate(
          offset: const Offset(0, -5),
          child: Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: widget.isGridView ? 10.0 : 12.0,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostContent(String location, TextStyle textStyle) {
    final String mediaUrl = widget.postData['mediaUrl'] ?? '';
    final bool isInternal = widget.postData['isInternal'] == true;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => _navigateToPostDetail(context, widget.postData),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Colors.black.withOpacity(0.3),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.roboto(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12.0,
                  fontWeight: FontWeight.normal,
                ),
                children: [
                  TextSpan(text: location),
                  const TextSpan(text: ' - '),
                  TextSpan(
                    text: username ??
                        LocalizationService.instance.translate('unknown_user'),
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isInternal)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                LocalizationService.instance.translate('internal') ??
                    'INTERNAL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if ((widget.postData['text'] ?? '').isNotEmpty)
          Positioned(
            bottom: 5,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                widget.postData['text'] ?? '',
                style: textStyle.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Positioned(
          bottom: 100,
          right: 3,
          child: Column(
            children: [
              _buildIconButton(
                Icons.thumb_up,
                likes,
                hasLiked ? null : _handleLike,
                widget.isGridView ? 16.0 : 24.0,
              ),
              _buildIconButton(
                Icons.thumb_down,
                dislikes,
                hasDisliked ? null : _handleDislike,
                widget.isGridView ? 16.0 : 24.0,
              ),
              _buildViewIconWithNumber(views),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToPostDetail(BuildContext context, Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location =
        '${widget.postData['localNeighborhoodId']} - ${DateFormat('d.M. - HH:mm\'h\'').format((widget.postData['createdAt'] as Timestamp).toDate())}';

    final textStyle = GoogleFonts.oswald(
      color: Colors.white,
      fontSize: widget.isGridView ? 16.0 : 26.0,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 4.0,
          color: Colors.black.withOpacity(0.4),
          offset: const Offset(2.0, 2.0),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[800]!, width: 2.0),
      ),
      child: _buildPostContent(location, textStyle),
    );
  }
}
