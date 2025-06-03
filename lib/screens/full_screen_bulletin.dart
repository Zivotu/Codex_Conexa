import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

import '../models/bulletin.dart';
import '../services/location_service.dart';

class FullScreenBulletin extends StatefulWidget {
  final Bulletin bulletin;
  final String countryId;
  final String cityId;
  final String locationId;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final String username;

  const FullScreenBulletin({
    super.key,
    required this.bulletin,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    this.onLike,
    this.onDislike,
    this.onComment,
    this.onShare,
    this.onDownload,
    required this.username,
  });

  @override
  FullScreenBulletinState createState() => FullScreenBulletinState();
}

class FullScreenBulletinState extends State<FullScreenBulletin> {
  late final LocationService _locationService;
  String locationName = '';
  late Bulletin _currentBulletin;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _loadLocationName();
    _currentBulletin = widget.bulletin;
  }

  Future<void> _loadLocationName() async {
    try {
      final locationData = await _locationService.getLocationDocument(
        widget.countryId,
        widget.cityId,
        widget.locationId,
      );
      setState(() {
        locationName = locationData?['name'] ?? 'Unknown Location';
      });
    } catch (error) {
      debugPrint('Error loading location name: $error');
    }
  }

  Future<void> _updateFirestore() async {
    try {
      final collectionName =
          _currentBulletin.isInternal ? 'bulletin_board' : 'public_bullets';
      final docRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection(collectionName)
          .doc(_currentBulletin.id);

      await docRef.update({
        'likes': _currentBulletin.likes,
        'dislikes': _currentBulletin.dislikes,
        'userLiked': _currentBulletin.userLiked,
        'userDisliked': _currentBulletin.userDisliked,
        'comments': _currentBulletin.comments,
      });
    } catch (e) {
      debugPrint('Error updating Firestore: $e');
    }
  }

  void _handleLike() {
    if (_currentBulletin.userLiked) return;

    setState(() {
      _currentBulletin.likes++;
      _currentBulletin.userLiked = true;
      if (_currentBulletin.userDisliked) {
        _currentBulletin.dislikes--;
        _currentBulletin.userDisliked = false;
      }
    });
    _updateFirestore();
    widget.onLike?.call();
  }

  void _handleDislike() {
    if (_currentBulletin.userDisliked) return;

    setState(() {
      _currentBulletin.dislikes++;
      _currentBulletin.userDisliked = true;
      if (_currentBulletin.userLiked) {
        _currentBulletin.likes--;
        _currentBulletin.userLiked = false;
      }
    });
    _updateFirestore();
    widget.onDislike?.call();
  }

  Future<void> _handleComment() async {
    final TextEditingController commentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Comment on ${_currentBulletin.title}'),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(hintText: 'Enter your comment'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final commentText = commentController.text.trim();
                if (commentText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment cannot be empty')),
                  );
                  return;
                }
                final newComment = {
                  'text': commentText,
                  'author': widget.username,
                  'time': DateTime.now().toIso8601String(),
                };
                setState(() {
                  _currentBulletin.comments =
                      List.from(_currentBulletin.comments)..add(newComment);
                });
                _updateFirestore();
                Navigator.of(context).pop();
                widget.onComment?.call();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareBulletin() async {
    final String content = '''
Shared from Conexa (https://www.google.com)

${_currentBulletin.title}

${_currentBulletin.description}
''';

    if (_currentBulletin.imagePaths.isNotEmpty) {
      try {
        final List<XFile> xFiles = [];
        for (final imageUrl in _currentBulletin.imagePaths) {
          final response = await http.get(Uri.parse(imageUrl));
          final directory = await getTemporaryDirectory();
          final fileName = path.basename(imageUrl);
          final filePath = path.join(directory.path, fileName);
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          xFiles.add(XFile(file.path));
        }

        await Share.shareXFiles(xFiles, text: content);
      } catch (e) {
        debugPrint('Error sharing image: $e');
        await Share.share(content);
      }
    } else {
      await Share.share(content);
    }
    widget.onShare?.call();
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.yellow[700],
            title: const Text('Full Screen Image',
                style: TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => Image.asset(
                'assets/images/bulletin.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImages() {
    // Ako postoji barem jedna slika, prikazujemo je kao banner, a ostale kao preview
    if (_currentBulletin.imagePaths.isNotEmpty) {
      return Column(
        children: [
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: _currentBulletin.imagePaths.first,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator())),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/bulletin.png',
                  width: double.infinity,
                  height: 200,
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
                  child: Text(
                    _currentBulletin.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Prikaz ostalih slika (ako ih ima više od jedne)
          if (_currentBulletin.imagePaths.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _currentBulletin.imagePaths
                    .skip(1)
                    .map(
                      (url) => GestureDetector(
                        onTap: () => _openFullScreenImage(url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/bulletin.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );
    } else {
      return Image.asset(
        'assets/images/bulletin.png',
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      );
    }
  }

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            'Comments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ..._currentBulletin.comments.map(
          (comment) {
            final String author = comment['author'] ?? 'Unknown';
            final String text = comment['text'] ?? '';
            final String rawTime = comment['time'] ?? '';
            String formattedDate = rawTime;
            try {
              final dateTime = DateTime.parse(rawTime);
              formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
            } catch (_) {}
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(text),
                      const SizedBox(height: 4),
                      Text(formattedDate,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.thumb_up,
                  color: _currentBulletin.userLiked ? Colors.blue : Colors.grey,
                ),
                onPressed: _handleLike,
                tooltip: 'Like',
              ),
              Text('${_currentBulletin.likes}'),
            ],
          ),
          // Dislike
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.thumb_down,
                  color:
                      _currentBulletin.userDisliked ? Colors.red : Colors.grey,
                ),
                onPressed: _handleDislike,
                tooltip: 'Dislike',
              ),
              Text('${_currentBulletin.dislikes}'),
            ],
          ),
          // Comment
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.comment),
                onPressed: _handleComment,
                tooltip: 'Comment',
              ),
              Text('${_currentBulletin.comments.length}'),
            ],
          ),
          // Share
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareBulletin,
            tooltip: 'Share',
          ),
          // Download
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: widget.onDownload,
            tooltip: 'Download',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow[700],
        title: Text(
          locationName,
          style: const TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImages(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _currentBulletin.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
              _buildActionRow(),
              _buildComments(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
