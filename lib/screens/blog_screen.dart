import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/blog_model.dart';
import 'blog_details_screen.dart';
import 'create_blog_screen.dart';
import 'edit_blog_screen.dart';
import 'infos/info_notices.dart';
import '../services/user_service.dart';
import '../controllers/blog_controller.dart';
import '../services/localization_service.dart';

class BlogScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const BlogScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _BlogScreenState createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  List<Blog> blogs = [];
  late Future<bool> _locationAdminFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNoticesInfo(context);
    });
    _locationAdminFuture = _fetchLocationAdminStatus();
  }

  Future<void> _showNoticesInfo(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('show_notices_boarding') ?? true;

    if (shouldShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InfoNoticesScreen(),
        ),
      );
    }
  }

  Future<bool> _fetchLocationAdminStatus() async {
    bool isAdmin = await UserService().getLocationAdminStatus(
        FirebaseAuth.instance.currentUser!.uid, widget.locationId);
    print('Fetched locationAdmin status: $isAdmin');
    return isAdmin;
  }

  Future<void> _deleteBlog(Blog blog) async {
    try {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('blogs')
          .doc(blog.id)
          .delete();

      setState(() {
        blogs.remove(blog);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('blogDeleted') ??
                'Blog successfully deleted',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('deleteError') ??
                'Error deleting blog: $e',
          ),
        ),
      );
    }
  }

  void _editBlog(Blog blog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBlogScreen(
          blog: blog,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );
  }

  void _likeBlog(Blog blog) async {
    try {
      await BlogController(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      ).likeBlog(blog.id, widget.username);

      setState(() {
        if (!blog.likedUsers.contains(widget.username)) {
          blog.likes++;
          blog.likedUsers.add(widget.username);

          if (blog.dislikedUsers.contains(widget.username)) {
            blog.dislikes--;
            blog.dislikedUsers.remove(widget.username);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('likeError') ??
                'Error liking blog: $e',
          ),
        ),
      );
    }
  }

  void _dislikeBlog(Blog blog) async {
    try {
      await BlogController(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      ).dislikeBlog(blog.id, widget.username);

      setState(() {
        if (!blog.dislikedUsers.contains(widget.username)) {
          blog.dislikes++;
          blog.dislikedUsers.add(widget.username);

          if (blog.likedUsers.contains(widget.username)) {
            blog.likes--;
            blog.likedUsers.remove(widget.username);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('dislikeError') ??
                'Error disliking blog: $e',
          ),
        ),
      );
    }
  }

  void _shareBlog(BuildContext context, Blog blog) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final String text =
        '${blog.title}\n\n${blog.content}\n\n${localizationService.translate('share_brand') ?? " - Conexa.life"}';
    final List<XFile> attachments = [];

    if (blog.imageUrls.isNotEmpty) {
      try {
        for (String imageUrl in blog.imageUrls) {
          final response = await http.get(Uri.parse(imageUrl));
          final directory = await getTemporaryDirectory();
          final filePath = path.join(directory.path, 'shared_image.png');
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          attachments.add(XFile(file.path));
        }
      } catch (e) {
        print('Error downloading image: $e');
      }
    }

    if (attachments.isNotEmpty) {
      await Share.shareXFiles(attachments, text: text);
    } else {
      await Share.share(text);
    }

    // Update share count in Firestore
    try {
      await BlogController(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      ).incrementShareCount(blog.id);
    } catch (e) {
      print('Error updating share count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return FutureBuilder<bool>(
      future: _fetchLocationAdminStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
                child: Text(localizationService.translate('error') ??
                    'Error: ${snapshot.error}')),
          );
        } else {
          bool locationAdmin = snapshot.data ?? false;
          return Scaffold(
            appBar: AppBar(
              title: Text(localizationService.translate('blogs') ?? 'Blogs'),
              actions: [
                if (locationAdmin)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateBlogScreen(
                            username: widget.username,
                            countryId: widget.countryId,
                            cityId: widget.cityId,
                            locationId: widget.locationId,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                    ),
                    child: Text(
                      localizationService.translate('create') ?? 'Create',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('countries')
                  .doc(widget.countryId)
                  .collection('cities')
                  .doc(widget.cityId)
                  .collection('locations')
                  .doc(widget.locationId)
                  .collection('blogs')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text(localizationService.translate('error') ??
                          'Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text(
                          localizationService.translate('noBlogsAvailable') ??
                              'No blogs available'));
                } else {
                  blogs = snapshot.data!.docs.map((doc) {
                    return Blog.fromMap(
                        doc.data() as Map<String, dynamic>, doc.id);
                  }).toList();

                  return ListView.builder(
                    itemCount: blogs.length,
                    itemBuilder: (context, index) {
                      final blog = blogs[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BlogDetailsScreen(
                                blog: blog,
                                username: widget.username,
                                countryId: widget.countryId,
                                cityId: widget.cityId,
                                locationId: widget.locationId,
                                locationAdmin: locationAdmin,
                              ),
                            ),
                          );
                        },
                        child: _buildBlogItem(blog, locationAdmin),
                      );
                    },
                  );
                }
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildBlogItem(Blog blog, bool locationAdmin) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              blog.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: blog.imageUrls.first,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/images/tenant.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      ),
                    )
                  : Image.asset(
                      'assets/images/tenant.png',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    blog.title,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  blog.content.length > 100
                      ? '${blog.content.substring(0, 100)}...'
                      : blog.content,
                  style: const TextStyle(fontSize: 16.0),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlogDetailsScreen(
                            blog: blog,
                            username: widget.username,
                            countryId: widget.countryId,
                            cityId: widget.cityId,
                            locationId: widget.locationId,
                            locationAdmin: locationAdmin,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 12.0),
                    ),
                    child: Text(
                      localizationService.translate('readMore') ?? 'Read More',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
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
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.thumb_up,
                        color: blog.likedUsers.contains(widget.username)
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      onPressed: () => _likeBlog(blog),
                    ),
                    Text('${blog.likes}'),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.thumb_down,
                        color: blog.dislikedUsers.contains(widget.username)
                            ? Colors.red
                            : Colors.grey,
                      ),
                      onPressed: () => _dislikeBlog(blog),
                    ),
                    Text('${blog.dislikes}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareBlog(context, blog),
                ),
                if (locationAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editBlog(blog),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteBlog(blog),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
