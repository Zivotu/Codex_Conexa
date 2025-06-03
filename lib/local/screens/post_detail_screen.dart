// PostDetailScreen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/post_service.dart'; // Uvezite PostService

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  PostDetailScreenState createState() => PostDetailScreenState();
}

class PostDetailScreenState extends State<PostDetailScreen> {
  int likes = 0;
  int dislikes = 0;
  int shares = 0;
  int reports = 0;
  bool hasLiked = false;
  bool hasDisliked = false;
  String? username;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoEnded = false;
  final Logger _logger = Logger();

  // Instanca PostService
  final PostService _postService = PostService();

  @override
  void initState() {
    super.initState();
    _logger.d("PostData in PostDetailScreen: ${widget.post}");

    final String postId = widget.post['postId'] ?? '';
    final String userId = widget.post['userId'] ?? '';
    final String country = widget.post['localCountryId'] ?? 'Nepoznata država';
    final String city = widget.post['localCityId'] ?? 'Nepoznati grad';
    final String neighborhood =
        widget.post['localNeighborhoodId'] ?? 'Nepoznati kvart';
    final bool isVideo = widget.post['isVideo'] ?? false;

    _logger.d(
        "postId: $postId, userId: $userId, country: $country, city: $city, neighborhood: $neighborhood, isVideo: $isVideo");

    if (postId.isNotEmpty && userId.isNotEmpty) {
      _postService.updatePostViews(postId, userId, country, city, neighborhood);
    }

    if (isVideo) {
      final String mediaUrl = widget.post['mediaUrl'] ?? '';
      if (mediaUrl.isNotEmpty) {
        _videoController = VideoPlayerController.network(mediaUrl)
          ..initialize().then((_) {
            setState(() {
              _isVideoInitialized = true;
              _videoController!.play();
              _videoController!.setVolume(1.0);
              _videoController!.addListener(_videoListener);
            });
          }).catchError((error) {
            _logger.e("Error initializing video: $error");
          });
      } else {
        _logger.w("isVideo is true but mediaUrl is empty.");
      }
    }

    _loadMetricsFromFirestore();
    _checkUserInteraction();
    _loadUsername();
  }

  void _videoListener() {
    if (_videoController != null &&
        _videoController!.value.position >= _videoController!.value.duration) {
      setState(() {
        _isVideoEnded = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _reportPost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Potvrda prijave'),
          content:
              const Text('Da li ste sigurni da želite prijaviti ovaj post?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Otkaži'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Prijavi'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final String postId = widget.post['postId'] ?? '';
      final String countryId =
          widget.post['localCountryId'] ?? 'unknown_country';
      final String cityId = widget.post['localCityId'] ?? 'unknown_city';
      final String neighborhoodId =
          widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';

      if (postId.isEmpty) {
        _logger.e("Cannot report post: postId is empty.");
        _showError('Nije moguće prijaviti post.');
        return;
      }

      try {
        final String metricsPath =
            'local_community/$countryId/cities/$cityId/neighborhoods/$neighborhoodId/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

        await FirebaseFirestore.instance.doc(metricsPath).set(
          {
            'reports': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );

        final String reportsPath =
            'reported_posts/${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseFirestore.instance.doc(reportsPath).set({
          'postId': postId,
          'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user',
          'timestamp': FieldValue.serverTimestamp(),
          'reason': 'Inappropriate content',
        });
      } catch (e) {
        _logger.e('Error reporting post: $e');
        _showError('Neuspjeh pri prijavljivanju posta.');
      }
    }
  }

  Future<void> _loadUsername() async {
    try {
      final String? userId = widget.post['userId'];
      if (userId != null && userId.isNotEmpty) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userSnapshot.exists) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          setState(() {
            username = userData['username'] ?? 'Unknown User';
          });
        } else {
          setState(() {
            username = 'Unknown User';
          });
          _logger.w('User document not found for userId: $userId');
        }
      } else {
        setState(() {
          username = 'Unknown User';
        });
        _logger.w('userId is null or empty.');
      }
    } catch (e) {
      _logger.e('Error loading username: $e');
      setState(() {
        username = 'Unknown User';
      });
    }
  }

  Future<void> _loadMetricsFromFirestore() async {
    try {
      final String postId = widget.post['postId'] ?? '';
      final String country = widget.post['localCountryId'] ?? 'unknown_country';
      final String city = widget.post['localCityId'] ?? 'unknown_city';
      final String neighborhood =
          widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';

      if (postId.isEmpty) {
        _logger.e("Cannot load metrics: postId is empty.");
        return;
      }

      final String metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      DocumentSnapshot metricsSnapshot =
          await FirebaseFirestore.instance.doc(metricsPath).get();

      if (metricsSnapshot.exists) {
        final data = metricsSnapshot.data() as Map<String, dynamic>;
        setState(() {
          likes = data['likes'] ?? 0;
          dislikes = data['dislikes'] ?? 0;
          shares = data['shares'] ?? 0;
          reports = data['reports'] ?? 0;
        });
      } else {
        await FirebaseFirestore.instance.doc(metricsPath).set({
          'likes': 0,
          'dislikes': 0,
          'shares': 0,
          'reports': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          likes = 0;
          dislikes = 0;
          shares = 0;
          reports = 0;
        });
      }
    } catch (e) {
      _logger.e('Error loading metrics from Firestore: $e');
    }
  }

  Future<void> _checkUserInteraction() async {
    try {
      final String postId = widget.post['postId'] ?? '';
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (postId.isEmpty || userId == null || userId.isEmpty) {
        _logger.w("Cannot check user interaction: postId or userId is empty.");
        return;
      }

      final DocumentReference userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      DocumentSnapshot interactionSnapshot = await userInteractionDoc.get();

      if (interactionSnapshot.exists) {
        final data = interactionSnapshot.data() as Map<String, dynamic>;
        setState(() {
          hasLiked = data['hasLiked'] ?? false;
          hasDisliked = data['hasDisliked'] ?? false;
        });
      }
    } catch (e) {
      _logger.e('Error checking user interaction: $e');
    }
  }

  Future<void> _handleLike() async {
    if (hasLiked || hasDisliked) return;

    try {
      final String postId = widget.post['postId'] ?? '';
      final String userId = widget.post['userId'] ?? '';
      final String country = widget.post['localCountryId'] ?? 'unknown_country';
      final String city = widget.post['localCityId'] ?? 'unknown_city';
      final String neighborhood =
          widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';

      if (postId.isEmpty || userId.isEmpty) {
        _logger.e("Cannot handle like: postId or userId is empty.");
        _showError('Neuspješno lajkanje posta.');
        return;
      }

      setState(() {
        likes++;
        hasLiked = true;
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final String metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';
      final String postPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final DocumentReference communityMetricsRef =
          FirebaseFirestore.instance.doc(metricsPath);
      final DocumentReference postRef =
          FirebaseFirestore.instance.doc(postPath);

      batch.set(
        communityMetricsRef,
        {'likes': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      batch.set(
        postRef,
        {'likes': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      final DocumentReference userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      batch.set(userInteractionDoc, {
        'hasLiked': true,
        'hasDisliked': false,
      });

      await batch.commit();
      await _loadMetricsFromFirestore();
    } catch (e) {
      setState(() {
        likes--;
        hasLiked = false;
      });
      _logger.e("Error updating likes: $e");
      _showError('Neuspješno lajkanje posta.');
    }
  }

  Future<void> _handleDislike() async {
    if (hasLiked || hasDisliked) return;

    try {
      final String postId = widget.post['postId'] ?? '';
      final String userId = widget.post['userId'] ?? '';
      final String country = widget.post['localCountryId'] ?? 'unknown_country';
      final String city = widget.post['localCityId'] ?? 'unknown_city';
      final String neighborhood =
          widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';

      if (postId.isEmpty || userId.isEmpty) {
        _logger.e("Cannot handle dislike: postId or userId is empty.");
        _showError('Neuspješno dislajkanje posta.');
        return;
      }

      setState(() {
        dislikes++;
        hasDisliked = true;
      });

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final String metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';
      final String postPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      final DocumentReference communityMetricsRef =
          FirebaseFirestore.instance.doc(metricsPath);
      final DocumentReference postRef =
          FirebaseFirestore.instance.doc(postPath);

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

      final DocumentReference userInteractionDoc = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('postInteractions')
          .doc(userId);

      batch.set(userInteractionDoc, {
        'hasLiked': false,
        'hasDisliked': true,
      });

      await batch.commit();
      await _loadMetricsFromFirestore();
    } catch (e) {
      setState(() {
        dislikes--;
        hasDisliked = false;
      });
      _logger.e("Error updating dislikes: $e");
      _showError('Neuspješno dislajkanje posta.');
    }
  }

  Future<void> _sharePost() async {
    final String displayUsername = (widget.post['isAnonymous'] ?? false)
        ? 'Anonimni korisnik'
        : (username ?? "Nepoznati korisnik");

    final String text = '${widget.post['text'] ?? ''}\n\n'
        'Objavio: $displayUsername';

    if (widget.post['mediaUrl'] != null && widget.post['mediaUrl'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(widget.post['mediaUrl']));
        if (response.statusCode == 200) {
          final directory = await getTemporaryDirectory();
          final String filePath = path.join(directory.path, 'shared_image.png');
          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          await Share.shareXFiles([XFile(file.path)], text: text);
        } else {
          _logger.e("Failed to download mediaUrl: ${widget.post['mediaUrl']}");
          await Share.share(text);
        }
      } catch (e) {
        _logger.e('Greška pri dijeljenju slike: $e');
        await Share.share(text);
      }
    } else {
      await Share.share(text);
    }

    final String postId = widget.post['postId'] ?? '';
    final String country = widget.post['localCountryId'] ?? 'unknown_country';
    final String city = widget.post['localCityId'] ?? 'unknown_city';
    final String neighborhood =
        widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';

    if (postId.isEmpty) {
      _logger.e("Cannot share post: postId is empty.");
      return;
    }

    try {
      final String metricsPath =
          'local_community/$country/cities/$city/neighborhoods/$neighborhood/metrics_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}/$postId';

      await FirebaseFirestore.instance.doc(metricsPath).set(
        {
          'shares': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      await _loadMetricsFromFirestore();
    } catch (e) {
      _logger.e("Error updating shares: $e");
      _showError('Neuspješno dijeljenje posta.');
    }
  }

  Future<void> _deletePost() async {
    final String postId = widget.post['postId'] ?? '';
    final String userId = widget.post['userId'] ?? '';
    final String countryId = widget.post['localCountryId'] ?? 'unknown_country';
    final String cityId = widget.post['localCityId'] ?? 'unknown_city';
    final String neighborhoodId =
        widget.post['localNeighborhoodId'] ?? 'unknown_neighborhood';
    final Timestamp? createdAtTimestamp = widget.post['createdAt'];

    _logger.d(
        "Deleting post with postId: $postId, userId: $userId, countryId: $countryId, cityId: $cityId, neighborhoodId: $neighborhoodId, createdAt: $createdAtTimestamp");

    if (postId.isEmpty || userId.isEmpty || createdAtTimestamp == null) {
      _logger.e(
          'Missing required fields for deleting post. postId: "$postId", userId: "$userId", createdAt: "$createdAtTimestamp"');
      _showError('Neki od potrebnih podataka za brisanje posta nedostaju.');
      return;
    }

    final DateTime createdAt = createdAtTimestamp.toDate();

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      _logger.e(
          'User is not authorized to delete this post. Current user ID: "${currentUser?.uid}", Post user ID: "$userId"');
      _showError('Nemate ovlaštenje za brisanje ovog posta.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Potvrda brisanja'),
          content:
              const Text('Da li ste sigurni da želite obrisati ovaj post?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Otkaži'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Obriši'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _postService.deletePost(
          postId,
          userId,
          countryId,
          cityId,
          neighborhoodId,
          createdAt,
        );

        Navigator.pop(context);
      } catch (e) {
        _logger.e("Greška pri brisanju posta: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neuspjeh pri brisanju posta.')),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildIconWithNumber(
      IconData icon, VoidCallback? onPressed, int count) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: Colors.white,
            shadows: const [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
          iconSize: 24.0,
          onPressed: onPressed,
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        const SizedBox(width: 0),
        Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 11.0),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? mediaUrl = widget.post['mediaUrl'];
    final bool hasImage = mediaUrl != null && mediaUrl.isNotEmpty;
    final String text = widget.post['text'] ?? 'Nema teksta';
    final String dateTime = widget.post['createdAt'] != null
        ? DateFormat('d.M.yyyy. - HH:mm\'h\'')
            .format((widget.post['createdAt'] as Timestamp).toDate())
        : 'Nepoznat datum';

    final String displayUsername = (widget.post['isAnonymous'] ?? false)
        ? 'Anonimni korisnik'
        : (username ?? 'Nepoznati korisnik');

    // Provjera vlasništva
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner =
        currentUser != null && currentUser.uid == widget.post['userId'];

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Container(
          color: Colors.black87,
          child: Stack(
            children: [
              // Gornja traka s korisničkim imenom i datumom (bez lokacije)
              Positioned(
                top: 35,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateTime,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                top: 28,
                child: hasImage
                    ? (widget.post['isVideo'] == true && _isVideoInitialized
                        ? AspectRatio(
                            aspectRatio:
                                widget.post['aspectRatio']?.toDouble() ?? 1.0,
                            child: VideoPlayer(_videoController!),
                          )
                        : Image.network(
                            mediaUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey,
                                child: const Center(
                                  child: Icon(Icons.error),
                                ),
                              );
                            },
                          ))
                    : Container(color: Colors.grey),
              ),
              if (text.isNotEmpty)
                Positioned(
                  bottom: 55,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.black.withOpacity(0.5),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Positioned(
                bottom: 2,
                left: 5,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconWithNumber(Icons.thumb_up, _handleLike, likes),
                    _buildIconWithNumber(
                        Icons.thumb_down, _handleDislike, dislikes),
                    _buildIconWithNumber(Icons.share, _sharePost, shares),
                    _buildIconWithNumber(Icons.report, _reportPost, reports),
                    _buildIconWithNumber(
                        Icons.visibility, null, widget.post['views'] ?? 0),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _deletePost,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 75,
                left: 0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
