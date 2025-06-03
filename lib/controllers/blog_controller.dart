import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blog_model.dart';

class BlogController {
  final String countryId;
  final String cityId;
  final String locationId;
  final CollectionReference<Map<String, dynamic>> _blogsCollection;

  BlogController({
    required this.countryId,
    required this.cityId,
    required this.locationId,
  }) : _blogsCollection = FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('blogs');

  // Method to create a new blog
  Future<void> createBlog(Blog blog) async {
    if (blog.createdBy.isEmpty) {
      throw Exception('Polje createdBy mora biti postavljeno prije spremanja.');
    }

    final docRef = await _blogsCollection.add(blog.toMap());
    blog.id = docRef.id; // Update the blog's ID after Firestore assigns it
    await docRef.update({'id': docRef.id}); // Save the ID back to Firestore
  }

  Future<void> updateBlog(Blog blog) async {
    if (blog.createdBy.isEmpty) {
      throw Exception(
          'Polje createdBy ne smije biti prazno prilikom ažuriranja.');
    }
    await _blogsCollection.doc(blog.id).update(blog.toMap());
  }

  // Method to vote on a poll
  Future<void> voteOnPoll(
      String blogId, int optionIndex, String username) async {
    final blogRef = _blogsCollection.doc(blogId);
    final blogSnapshot = await blogRef.get();
    final blogData = blogSnapshot.data();

    if (blogData == null) {
      throw Exception('Blog not found');
    }

    final List<Map<String, dynamic>> pollOptions =
        List<Map<String, dynamic>>.from(blogData['pollOptions']);
    pollOptions[optionIndex]['votes'] += 1;

    final List<String> votedUsers = List<String>.from(blogData['votedUsers']);
    if (votedUsers.contains(username)) {
      throw Exception('User has already voted');
    }
    votedUsers.add(username);

    await blogRef.update({
      'pollOptions': pollOptions,
      'votedUsers': votedUsers,
    });
  }

  // Method to like a blog
  Future<void> likeBlog(String blogId, String username) async {
    final blogRef = _blogsCollection.doc(blogId);
    final blogSnapshot = await blogRef.get();
    final blogData = blogSnapshot.data();

    if (blogData == null) {
      throw Exception('Blog not found');
    }

    final List<String> likedUsers =
        List<String>.from(blogData['likedUsers'] ?? []);
    final List<String> dislikedUsers =
        List<String>.from(blogData['dislikedUsers'] ?? []);

    if (likedUsers.contains(username)) {
      throw Exception('User has already liked this blog');
    }

    likedUsers.add(username);

    await blogRef.update({
      'likes': FieldValue.increment(1),
      'likedUsers': likedUsers,
      if (dislikedUsers.contains(username))
        'dislikedUsers': FieldValue.arrayRemove([username]),
      if (dislikedUsers.contains(username))
        'dislikes': FieldValue.increment(-1),
    });
  }

  // Method to dislike a blog
  Future<void> dislikeBlog(String blogId, String username) async {
    final blogRef = _blogsCollection.doc(blogId);
    final blogSnapshot = await blogRef.get();
    final blogData = blogSnapshot.data();

    if (blogData == null) {
      throw Exception('Blog not found');
    }

    final List<String> likedUsers =
        List<String>.from(blogData['likedUsers'] ?? []);
    final List<String> dislikedUsers =
        List<String>.from(blogData['dislikedUsers'] ?? []);

    if (dislikedUsers.contains(username)) {
      throw Exception('User has already disliked this blog');
    }

    dislikedUsers.add(username);

    await blogRef.update({
      'dislikes': FieldValue.increment(1),
      'dislikedUsers': dislikedUsers,
      if (likedUsers.contains(username))
        'likedUsers': FieldValue.arrayRemove([username]),
      if (likedUsers.contains(username)) 'likes': FieldValue.increment(-1),
    });
  }

  // Method to delete a blog
  Future<void> deleteBlog(String blogId) async {
    await _blogsCollection.doc(blogId).delete();
  }

  // Method to increment the share count
  Future<void> incrementShareCount(String blogId) async {
    final blogRef = _blogsCollection.doc(blogId);
    await blogRef.update({
      'shares': FieldValue.increment(1),
    });
  }

  // Method to get a stream of blogs
  Stream<List<Blog>> getBlogs() {
    return _blogsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Blog.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
