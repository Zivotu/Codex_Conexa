// lib/local/screens/neighborhood_posts_screen.dart

import 'package:flutter/material.dart';
import '../services/post_service.dart';
import 'post_detail_screen.dart';
import 'post_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/localization_service.dart';
import 'package:provider/provider.dart';

/// ✨ MODEL ZA FILTER (ChangeNotifier)
///  (LocalHomeScreen ga već instancira i pruža)
class BuildingFilter extends ChangeNotifier {
  bool onlyBuilding;
  final Map<String, bool> selected; // locationId → checked

  BuildingFilter({this.onlyBuilding = false, Map<String, bool>? selected})
      : selected = selected ?? {};

  Set<String> get selectedIds =>
      selected.entries.where((e) => e.value).map((e) => e.key).toSet();

  void toggleOnlyBuilding(bool v) {
    onlyBuilding = v;
    notifyListeners();
  }

  void toggleBuilding(String id, bool v) {
    selected[id] = v;
    notifyListeners();
  }
}

class NeighborhoodPostsScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String neighborhood;

  const NeighborhoodPostsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.neighborhood,
  });

  @override
  NeighborhoodPostsScreenState createState() => NeighborhoodPostsScreenState();
}

class NeighborhoodPostsScreenState extends State<NeighborhoodPostsScreen> {
  final PostService _postService = PostService();
  List<Map<String, dynamic>> _posts = []; // Sirovi geo-postovi
  List<Map<String, dynamic>> _internalPosts = []; // Interni postovi zgrada
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _loadViewPreferences();
    _loadPosts(); // učitamo i geo i interne
  }

  /* ------------------------------------------------------------------ */
  /* -------------------------   LOADING DATA   ----------------------- */
  /* ------------------------------------------------------------------ */

  Future<void> _loadPosts() async {
    final filter = Provider.of<BuildingFilter>(context, listen: false);

    try {
      // 1) GEO-POSTOVI ZA KVART
      final geoSnap = await FirebaseFirestore.instance
          .collection('local_community')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('neighborhoods')
          .doc(widget.neighborhood)
          .collection(
              'posts_${DateTime.now().year}_${DateTime.now().month.toString().padLeft(2, '0')}')
          .orderBy('createdAt', descending: true)
          .get();

      final geoPosts =
          geoSnap.docs.map((d) => {'postId': d.id, ...d.data()}).toList();

      // 2) INTERNI POSTOVI ZA SVE OZNAČENE ZGRADE
      List<Map<String, dynamic>> internal = [];
      for (final locId in filter.selectedIds) {
        final snap = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locId)
            .collection('internal_posts')
            .orderBy('createdAt', descending: true)
            .get();
        internal.addAll(snap.docs.map((d) => {'postId': d.id, ...d.data()}));
      }

      setState(() {
        _posts = geoPosts;
        _internalPosts = internal;
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  /* ------------------------------------------------------------------ */
  /* -----------------------   VIEW PREFERENCE   ---------------------- */
  /* ------------------------------------------------------------------ */

  Future<void> _loadViewPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users_local')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() => _isGridView = doc['viewMode'] == 'grid');
      }
    }
  }

  Future<void> _saveViewPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users_local')
          .doc(user.uid)
          .set({'viewMode': _isGridView ? 'grid' : 'list'},
              SetOptions(merge: true));
    }
  }

  void _toggleViewMode() {
    setState(() => _isGridView = !_isGridView);
    _saveViewPreferences();
  }

  /* ------------------------------------------------------------------ */
  /* ------------------------   NAVIGACIJA   -------------------------- */
  /* ------------------------------------------------------------------ */

  void _navigateToPostDetail(BuildContext context, Map<String, dynamic> post) {
    final DateTime createdAt = (post['createdAt'] as Timestamp).toDate();
    _postService.updatePostViews(
      post['postId'],
      post['userId'],
      widget.countryId,
      widget.cityId,
      widget.neighborhood,
      createdAt,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  /* ------------------------------------------------------------------ */
  /* ---------------------------   UI   ------------------------------- */
  /* ------------------------------------------------------------------ */

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final filter = Provider.of<BuildingFilter>(context);

    // Kombiniramo i filtriramo
    final combined = [..._posts, ..._internalPosts];
    final displayed = combined.where((p) {
      final bool isInternal = p['isInternal'] == true;
      final String? locId = p['locationId'];
      if (filter.onlyBuilding) {
        return isInternal && filter.selectedIds.contains(locId);
      } else {
        return !isInternal || filter.selectedIds.contains(locId);
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.translate('posts_in')} ${widget.neighborhood}'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleViewMode,
          ),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _loadPosts();
              })
        ],
      ),
      body: Container(
        color: Colors.black,
        child: displayed.isEmpty
            ? Center(
                child: Text(
                  filter.onlyBuilding
                      ? loc.translate('no_posts_for_building') ??
                          'No posts for selected buildings'
                      : loc.translate('no_posts_available') ??
                          'No posts available',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : (_isGridView
                ? _buildGridView(displayed)
                : _buildListView(displayed)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => displayed.shuffle()),
        child:
            Icon(Icons.shuffle, semanticLabel: loc.translate('shuffle_posts')),
      ),
    );
  }

  /* --------------------  LIST & GRID BUILDERS  -------------------- */

  Widget _buildListView(List<Map<String, dynamic>> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(
        color: Colors.white,
        thickness: 1,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final post = list[index];
        return GestureDetector(
          onTap: () => _navigateToPostDetail(context, post),
          child: PostWidget(postData: post),
        );
      },
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> list) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final post = list[index];
        return GestureDetector(
          onTap: () => _navigateToPostDetail(context, post),
          child: PostWidget(postData: post),
        );
      },
    );
  }
}
