// lib/services/post_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../../services/localization_service.dart';
import '../constants/location_constants.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // =========================================================
  // 1) SPREMANJE POSTA (GEO + INTERNI DUPLIKAT + USER POSTS)
  // =========================================================
  Future<void> savePostToFirestore(
    Map<String, dynamic> postData,
    String postId,
    Map<String, dynamic> additionalData,
  ) async {
    try {
      final String countryId = additionalData['countryId'];
      final String cityId = additionalData['cityId'];
      final String neighborhood = additionalData['neighborhood'];

      // Lokalizirano korisničko ime za anonimne postove
      postData['username'] = postData['isAnonymous'] == true
          ? LocalizationService.instance.translate('anonymous')
          : postData['username'];

      // Flag i ID zgrade
      final bool isInternal = postData['isInternal'] == true;
      final String? locationId = postData['locationId'];

      // Ako su sve geo-komponente UNKNOWN → spremamo u „unknown_location”
      if (countryId == LocationConstants.UNKNOWN_COUNTRY &&
          cityId == LocationConstants.UNKNOWN_CITY &&
          neighborhood == LocationConstants.UNKNOWN_NEIGHBORHOOD) {
        postData['localLocationId'] = LocationConstants.UNKNOWN_LOCATION;
      }

      DateTime createdAt = fromDate ?? DateTime.now();

      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      // ------------- GEO-KOLEKCIJA -------------
      final String geoPath = postData.containsKey('localLocationId') &&
              postData['localLocationId'] == LocationConstants.UNKNOWN_LOCATION
          ? 'local_community/unknown_location/posts_${year}_$month'
          : 'local_community/$countryId/cities/$cityId/neighborhoods/$neighborhood/posts_${year}_$month';

      // ------------- BATCH WRITE -------------
      final batch = _firestore.batch();

      // (1) Geo-feed
      final geoRef = _firestore.collection(geoPath).doc(postId);
      batch.set(geoRef, postData);

      // (2) Interna kopija (samo ako je označeno kao zgrada-post)
      if (isInternal && locationId != null && locationId.isNotEmpty) {
        final internalRef = _firestore
            .collection('locations')
            .doc(locationId)
            .collection('internal_posts')
            .doc(postId);
        batch.set(internalRef, postData);
      }

      // (3) Kopija pod korisnikom
      final userPostRef = _firestore
          .collection('users')
          .doc(postData['userId'])
          .collection('userPosts')
          .doc(postId);
      batch.set(userPostRef, postData, SetOptions(merge: true));

      await batch.commit();
      _logger.i('Post $postId saved (geo + internal if needed).');

      // (4) Inicijalizacija metrika
      await updatePostMetrics(
        countryId,
        cityId,
        neighborhood,
        postId,
        createdAt,
        likes: 0,
        dislikes: 0,
        views: 0,
        shares: 0,
      );
    } catch (e) {
      _logger.e('Error saving post: $e');
    }
  }

  // =========================================================
  // 2) BROJANJE POSTOVA
  // =========================================================
  Future<int> getPostCount({
    required String countryId,
    String? cityId,
    String? neighborhoodId,
    DateTime? fromDate,
    bool isCountry = false,
    bool isCity = false,
    bool isNeighborhood = false,
    bool isUnknownLocation = false,
  }) async {
    try {
      CollectionReference postCollection;

      // Determine the year and month based on the provided [fromDate]
      // so that the correct monthly collection can be queried. If no
      // starting date is supplied, default to the current date.
      DateTime createdAt = fromDate ?? DateTime.now();

      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      if (isUnknownLocation) {
        postCollection = _firestore
            .collection('local_community')
            .doc(LocationConstants.UNKNOWN_LOCATION)
            .collection('posts_${year}_$month');
      } else if (isNeighborhood && neighborhoodId != null) {
        postCollection = _firestore
            .collection('local_community')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('neighborhoods')
            .doc(neighborhoodId)
            .collection('posts_${year}_$month');
      } else if (isCity && cityId != null) {
        postCollection = _firestore
            .collection('local_community')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('posts_${year}_$month');
      } else if (isCountry) {
        postCollection = _firestore
            .collection('local_community')
            .doc(countryId)
            .collection('posts_${year}_$month');
      } else {
        throw ArgumentError('Invalid location provided for post count.');
      }

      final query = fromDate != null
          ? postCollection.where('createdAt', isGreaterThanOrEqualTo: fromDate)
          : postCollection;

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error fetching post count: $e');
      return 0;
    }
  }

  // =========================================================
  // 3) LAJK
  // =========================================================
  Future<void> likePost(
    String postId,
    String userId,
    String countryId,
    String cityId,
    String neighborhoodId,
    Map<String, dynamic> postData,
  ) async {
    try {
      DateTime createdAt;
      if (postData['createdAt'] is Timestamp) {
        createdAt = (postData['createdAt'] as Timestamp).toDate();
      } else if (postData['createdAt'] is DateTime) {
        createdAt = postData['createdAt'] as DateTime;
      } else {
        createdAt = DateTime.now();
      }

      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final postRef = _firestore
          .collection('local_community')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('neighborhoods')
          .doc(neighborhoodId)
          .collection('posts_${year}_$month')
          .doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (snapshot.exists) {
          final currentLikes = snapshot.data()?['likes'] ?? 0;
          transaction.update(postRef, {
            'likes': currentLikes + 1,
            'lastLikedBy': {
              'userId': userId,
              'username': postData['isAnonymous'] == true
                  ? LocalizationService.instance.translate('anonymous')
                  : postData['username'],
            },
            'lastLikedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      final userPostRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .doc(postId);

      await userPostRef.update({
        'likes': FieldValue.increment(1),
        'lastLikedBy': postData['isAnonymous'] == true
            ? LocalizationService.instance.translate('anonymous')
            : postData['username'],
        'lastLikedAt': FieldValue.serverTimestamp(),
      });

      await updatePostMetrics(
        countryId,
        cityId,
        neighborhoodId,
        postId,
        createdAt,
        likes: 1,
      );
    } catch (e) {
      _logger.e('Error liking post: $e');
    }
  }

  // =========================================================
  // 4) DIJELJENJE
  // =========================================================
  Future<void> sharePost(
    String postId,
    String userId,
    String countryId,
    String cityId,
    String neighborhoodId,
    Map<String, dynamic> postData,
  ) async {
    try {
      DateTime createdAt;
      if (postData['createdAt'] is Timestamp) {
        createdAt = (postData['createdAt'] as Timestamp).toDate();
      } else if (postData['createdAt'] is DateTime) {
        createdAt = postData['createdAt'] as DateTime;
      } else {
        createdAt = DateTime.now();
      }

      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final postRef = _firestore
          .collection('local_community')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('neighborhoods')
          .doc(neighborhoodId)
          .collection('posts_${year}_$month')
          .doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (snapshot.exists) {
          final currentShares = snapshot.data()?['shares'] ?? 0;
          transaction.update(postRef, {'shares': currentShares + 1});
        }
      });

      final userPostRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .doc(postId);

      await userPostRef.update({
        'shares': FieldValue.increment(1),
        'lastSharedBy': postData['isAnonymous'] == true
            ? LocalizationService.instance.translate('anonymous')
            : postData['username'],
      });

      await updatePostMetrics(
        countryId,
        cityId,
        neighborhoodId,
        postId,
        createdAt,
        shares: 1,
      );
    } catch (e) {
      _logger.e('Error sharing post: $e');
    }
  }

  // =========================================================
  // 5) VIEW COUNT
  // =========================================================
  Future<void> updatePostViews(
    String postId,
    String userId,
    String countryId,
    String cityId,
    String neighborhoodId,
    DateTime createdAt,
  ) async {
    try {
      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final postRef = _firestore
          .collection('local_community')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('neighborhoods')
          .doc(neighborhoodId)
          .collection('posts_${year}_$month')
          .doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (snapshot.exists) {
          final currentViews = snapshot.data()?['views'] ?? 0;
          transaction.update(postRef, {'views': currentViews + 1});
        }
      });

      final userPostRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .doc(postId);

      await userPostRef.update({'views': FieldValue.increment(1)});

      await updatePostMetrics(
        countryId,
        cityId,
        neighborhoodId,
        postId,
        createdAt,
        views: 1,
      );
    } catch (e) {
      _logger.e('Error updating post views: $e');
    }
  }

  // =========================================================
  // 6) ČITANJE METRIKA
  // =========================================================
  Future<Map<String, dynamic>> getPostMetrics(
    String countryId,
    String cityId,
    String neighborhoodId,
    String postId,
    DateTime createdAt,
  ) async {
    try {
      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final metricsRef = _firestore
          .collection('local_community')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('neighborhoods')
          .doc(neighborhoodId)
          .collection('metrics_${year}_$month')
          .doc(postId);

      final doc = await metricsRef.get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;

      _logger.w('Metrics document does not exist for post $postId.');
      return {
        'likes': 0,
        'dislikes': 0,
        'views': 0,
        'shares': 0,
        'lastUpdated': null,
      };
    } catch (e) {
      _logger.e('Error fetching post metrics: $e');
      return {
        'likes': 0,
        'dislikes': 0,
        'views': 0,
        'shares': 0,
        'lastUpdated': null,
      };
    }
  }

  // =========================================================
  // 7) BRISANJE POSTA
  // =========================================================
  Future<void> deletePost(
    String postId,
    String userId,
    String countryId,
    String cityId,
    String neighborhoodId,
    DateTime createdAt,
  ) async {
    try {
      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final String path = countryId == LocationConstants.UNKNOWN_COUNTRY &&
              cityId == LocationConstants.UNKNOWN_CITY &&
              neighborhoodId == LocationConstants.UNKNOWN_NEIGHBORHOOD
          ? 'local_community/unknown_location/posts_${year}_$month'
          : 'local_community/$countryId/cities/$cityId/neighborhoods/$neighborhoodId/posts_${year}_$month';

      await _firestore.collection(path).doc(postId).delete();

      final userPostRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('userPosts')
          .doc(postId);
      await userPostRef.delete();

      _logger.i('Post $postId deleted from all collections.');
    } catch (e) {
      _logger.e('Error deleting post: $e');
    }
  }

  // =========================================================
  // 8) AŽURIRANJE METRIKA
  // =========================================================
  Future<void> updatePostMetrics(
    String countryId,
    String cityId,
    String neighborhoodId,
    String postId,
    DateTime createdAt, {
    int likes = 0,
    int dislikes = 0,
    int views = 0,
    int shares = 0,
  }) async {
    try {
      final String year = createdAt.year.toString();
      final String month = createdAt.month.toString().padLeft(2, '0');

      final CollectionReference metricsCollection =
          (countryId == LocationConstants.UNKNOWN_COUNTRY &&
                  cityId == LocationConstants.UNKNOWN_CITY &&
                  neighborhoodId == LocationConstants.UNKNOWN_NEIGHBORHOOD)
              ? _firestore
                  .collection('local_community')
                  .doc(LocationConstants.UNKNOWN_LOCATION)
                  .collection('metrics_${year}_$month')
              : _firestore
                  .collection('local_community')
                  .doc(countryId)
                  .collection('cities')
                  .doc(cityId)
                  .collection('neighborhoods')
                  .doc(neighborhoodId)
                  .collection('metrics_${year}_$month');

      await metricsCollection.doc(postId).set({
        'postId': postId,
        'likes': FieldValue.increment(likes),
        'dislikes': FieldValue.increment(dislikes),
        'views': FieldValue.increment(views),
        'shares': FieldValue.increment(shares),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _logger.i('Metrics updated for post $postId.');
    } catch (e) {
      _logger.e('Error updating post metrics: $e');
    }
  }
}
