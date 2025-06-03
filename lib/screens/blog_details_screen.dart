import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../models/blog_model.dart';
import '../controllers/blog_controller.dart';
import '../services/localization_service.dart';

class BlogDetailsScreen extends StatefulWidget {
  final Blog blog;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final bool locationAdmin;

  const BlogDetailsScreen({
    super.key,
    required this.blog,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationAdmin,
  });

  @override
  BlogDetailsScreenState createState() => BlogDetailsScreenState();
}

class BlogDetailsScreenState extends State<BlogDetailsScreen> {
  late final BlogController _blogController;
  final localization = LocalizationService.instance;

  @override
  void initState() {
    super.initState();
    _blogController = BlogController(
      countryId: widget.countryId,
      cityId: widget.cityId,
      locationId: widget.locationId,
    );
  }

  void _onLikeBlog() async {
    try {
      await _blogController.likeBlog(widget.blog.id, widget.username);

      setState(() {
        if (!widget.blog.likedUsers.contains(widget.username)) {
          widget.blog.likes++;
          widget.blog.likedUsers.add(widget.username);

          if (widget.blog.dislikedUsers.contains(widget.username)) {
            widget.blog.dislikes--;
            widget.blog.dislikedUsers.remove(widget.username);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localization.translate('like_error') ?? 'Error liking blog',
          ),
        ),
      );
    }
  }

  void _onDislikeBlog() async {
    try {
      await _blogController.dislikeBlog(widget.blog.id, widget.username);

      setState(() {
        if (!widget.blog.dislikedUsers.contains(widget.username)) {
          widget.blog.dislikes++;
          widget.blog.dislikedUsers.add(widget.username);

          if (widget.blog.likedUsers.contains(widget.username)) {
            widget.blog.likes--;
            widget.blog.likedUsers.remove(widget.username);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localization.translate('dislike_error') ?? 'Error disliking blog',
          ),
        ),
      );
    }
  }

  void _shareBlog() async {
    final String text =
        '${widget.blog.title}\n\n${widget.blog.content}\n\n${localization.translate('share_brand') ?? ' - Conexa.life'}';
    final List<XFile> attachments = [];

    if (widget.blog.imageUrls.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(widget.blog.imageUrls.first));
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, 'shared_image.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        attachments.add(XFile(file.path));
      } catch (e) {
        debugPrint('Error downloading image: $e');
      }
    }

    if (attachments.isNotEmpty) {
      await Share.shareXFiles(attachments, text: text);
    } else {
      await Share.share(text);
    }
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localization.translate('image_view') ?? 'Image View',
          ),
        ),
        body: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => Image.asset(
              'assets/images/tenant.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }));
  }

  Widget _buildImagePreviews(List<String> imageUrls) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: imageUrls.map((imageUrl) {
          return GestureDetector(
            onTap: () => _openFullScreenImage(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/tenant.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPoll() {
    if (widget.blog.pollQuestion.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16.0),
            Text(
              widget.blog.pollQuestion,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10.0),
            ...widget.blog.pollOptions.map((option) {
              final index = widget.blog.pollOptions.indexOf(option);
              final isVoted = widget.blog.votedUsers.contains(widget.username);
              return ListTile(
                title: Text(option['option']),
                trailing: isVoted
                    ? Text(
                        '${option['votes']} ${localization.translate('votes') ?? 'votes'}',
                        style: const TextStyle(fontSize: 16),
                      )
                    : ElevatedButton(
                        onPressed: () => _onVote(index),
                        child: Text(
                          localization.translate('vote') ?? 'Vote',
                        ),
                      ),
              );
            }),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _onVote(int optionIndex) async {
    try {
      await _blogController.voteOnPoll(
          widget.blog.id, optionIndex, widget.username);

      setState(() {
        widget.blog.pollOptions[optionIndex]['votes'] += 1;
        widget.blog.votedUsers.add(widget.username);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localization.translate('vote_error') ?? 'Error voting',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDefaultImage = widget.blog.imageUrls.isEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          localization.translate('blog_details') ?? 'Blog Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
      ),
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
              Stack(
                children: [
                  isDefaultImage
                      ? Image.asset(
                          'assets/images/tenant.png',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.blog.imageUrls.first,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/tenant.png',
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
                      color: Colors.black.withOpacity(0.6),
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        widget.blog.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isDefaultImage) _buildImagePreviews(widget.blog.imageUrls),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.blog.content,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildPoll(),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.thumb_up,
                            color:
                                widget.blog.likedUsers.contains(widget.username)
                                    ? Colors.blue
                                    : Colors.grey,
                          ),
                          onPressed: _onLikeBlog,
                          tooltip: localization.translate('like') ?? 'Like',
                        ),
                        Text(
                          '${widget.blog.likes}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.thumb_down,
                            color: widget.blog.dislikedUsers
                                    .contains(widget.username)
                                ? Colors.red
                                : Colors.grey,
                          ),
                          onPressed: _onDislikeBlog,
                          tooltip:
                              localization.translate('dislike') ?? 'Dislike',
                        ),
                        Text(
                          '${widget.blog.dislikes}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: _shareBlog,
                          tooltip: localization.translate('share') ?? 'Share',
                        ),
                        Text(
                          '${widget.blog.shares}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (widget.locationAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          // Implement delete functionality here
                        },
                        tooltip: localization.translate('delete') ?? 'Delete',
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
