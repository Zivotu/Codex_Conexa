// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/repair_request.dart';

class FirebaseService {
  final Logger _logger = Logger();

  // Metoda za dohvaćanje broja novih dokumenata
  Future<int> getNewDocumentsCount(String countryId, String cityId,
      String locationId, DateTime lastVisited) async {
    try {
      final newDocumentsSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('documents')
          .where('createdAt', isGreaterThan: lastVisited)
          .where('deleted', isEqualTo: false)
          .get();
      return newDocumentsSnapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting new documents count: $e');
      return 0;
    }
  }

  // Metoda za dohvaćanje najnovijeg sadržaja
  Stream<Map<String, dynamic>> fetchLatestContent(
      String countryId, String cityId, String locationId) {
    final locationPath =
        'countries/$countryId/cities/$cityId/locations/$locationId';
    return FirebaseFirestore.instance
        .collection('$locationPath/chats')
        .where('deleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .asyncMap((chatSnapshot) async {
      final latestChatMessage =
          chatSnapshot.docs.isNotEmpty ? chatSnapshot.docs.first.data() : {};

      final latestDocumentsSnapshot = await FirebaseFirestore.instance
          .collection('$locationPath/documents')
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final latestBulletinBoardSnapshot = await FirebaseFirestore.instance
          .collection('$locationPath/bulletin_board')
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final latestBlogsSnapshot = await FirebaseFirestore.instance
          .collection('$locationPath/blogs')
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      String latestChatText = '';
      String latestDocumentText = '';
      String latestBulletinText = '';
      String latestBlogText = '';

      if (latestChatMessage.isNotEmpty) {
        latestChatText = latestChatMessage.containsKey('text')
            ? latestChatMessage['text']
            : 'No text available';
      }

      if (latestDocumentsSnapshot.docs.isNotEmpty) {
        final documentData = latestDocumentsSnapshot.docs.first.data();
        latestDocumentText = documentData.containsKey('title')
            ? documentData['title']
            : 'No title available';
      }

      if (latestBulletinBoardSnapshot.docs.isNotEmpty) {
        final bulletinData = latestBulletinBoardSnapshot.docs.first.data();
        latestBulletinText = bulletinData.containsKey('title')
            ? bulletinData['title']
            : 'No title available';
      }

      if (latestBlogsSnapshot.docs.isNotEmpty) {
        final blogData = latestBlogsSnapshot.docs.first.data();
        latestBlogText = blogData.containsKey('title')
            ? blogData['title']
            : 'No title available';
      }

      return {
        'latestChatText': latestChatText,
        'latestDocumentText': latestDocumentText,
        'latestBulletinText': latestBulletinText,
        'latestBlogText': latestBlogText,
      };
    });
  }

  // Metoda za ažuriranje vremena posjete
  Future<void> updateVisitTime(String userId, String categoryId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryId)
        .set({
      'lastVisited': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Metoda za dodavanje lokacije
  Future<void> addLocation(BuildContext context, String username,
      String countryId, String cityId, String locationId) async {
    try {
      final newLocationRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId);

      await newLocationRef.set({
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'deleted': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokacija uspješno dodana')),
        );
      }
    } catch (e) {
      _logger.e('Error adding location: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri dodavanju lokacije: $e')),
        );
      }
    }
  }

  // Metoda za kreiranje novog bloga
  Future<void> createNewBlog(BuildContext context, String countryId,
      String cityId, String locationId) async {
    try {
      final newBlogRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('blogs')
          .doc();

      await newBlogRef.set({
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'title': 'Novi Blog',
        'content': 'Sadržaj bloga',
        'deleted': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blog uspješno kreiran')),
        );
      }
    } catch (e) {
      _logger.e('Error creating blog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri kreiranju bloga: $e')),
        );
      }
    }
  }

  // Metoda za dohvaćanje korisničkog dokumenta (koristi se samo za korisničke podatke)
  Future<Map<String, dynamic>?> getUserDocument(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data();
    } catch (e) {
      _logger.e('Error fetching user document: $e');
      return null;
    }
  }

  // Metoda za dohvaćanje broja novih stavki
  Future<int> getNewItemsCount(String countryId, String cityId,
      String locationId, String collectionPath, DateTime lastVisited) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection(collectionPath)
          .where('createdAt', isGreaterThan: lastVisited)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting new items count: $e');
      return 0;
    }
  }

  // Metoda za dohvaćanje broja novih poruka
  Stream<int> getNewMessagesCount(
      String countryId, String cityId, String locationId) {
    final collectionPath =
        'countries/$countryId/cities/$cityId/locations/$locationId/chats';
    return FirebaseFirestore.instance
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje broja novih objava
  Stream<int> getNewPostsCount(
      String countryId, String cityId, String locationId) {
    final collectionPath =
        'countries/$countryId/cities/$cityId/locations/$locationId/bulletin_board';
    return FirebaseFirestore.instance
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje broja novih dokumenata
  Stream<int> getNewDocumentsCountStream(
      String countryId, String cityId, String locationId) {
    final collectionPath =
        'countries/$countryId/cities/$cityId/locations/$locationId/documents';
    return FirebaseFirestore.instance
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje broja novih blogova
  Stream<int> getNewBlogsCount(
      String countryId, String cityId, String locationId) {
    final collectionPath =
        'countries/$countryId/cities/$cityId/locations/$locationId/blogs';
    return FirebaseFirestore.instance
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje broja novih biltena
  Stream<int> getNewBulletinsCount(
      String countryId, String cityId, String locationId) {
    final collectionPath =
        'countries/$countryId/cities/$cityId/locations/$locationId/bulletin_board';
    return FirebaseFirestore.instance
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje najnovijeg naslova sadržaja
  Future<String> getLatestContentTitle(String countryId, String cityId,
      String locationId, String categoryField) async {
    try {
      final latestSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection(categoryField)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (latestSnapshot.docs.isNotEmpty) {
        final latestDoc = latestSnapshot.docs.first.data();
        if (categoryField == 'chats') {
          return latestDoc['text'] ?? 'No message available';
        } else {
          return latestDoc['title'] ?? 'No title available';
        }
      } else {
        return 'No content available';
      }
    } catch (e) {
      _logger.e('Error getting latest content title: $e');
      return 'Error fetching content';
    }
  }

  // Stream za najnoviji naslov sadržaja
  Stream<String> getLatestContentTitleStream(String countryId, String cityId,
      String locationId, String categoryField) {
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection(categoryField)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestDoc = snapshot.docs.first.data();
        return latestDoc['title'] ??
            latestDoc['text'] ??
            'No content available';
      } else {
        return 'No content available';
      }
    });
  }

  // Stream za broj novih objava unutar zadnjih 12 sati
  Stream<int> getNewPostsCountStream(String countryId, String cityId,
      String locationId, String categoryField) {
    final DateTime last12Hours =
        DateTime.now().subtract(const Duration(hours: 12));
    return FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection(categoryField)
        .where('createdAt', isGreaterThan: last12Hours)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Metoda za dohvaćanje najnovijeg aktivnog zahtjeva za popravak
  // Metoda za dohvaćanje najnovijeg aktivnog zahtjeva za popravak
  // Metoda za dohvaćanje najnovijeg aktivnog zahtjeva za popravak
  // firebase_service.dart

// Metoda za dohvaćanje najnovijeg aktivnog zahtjeva za popravak bez filtera za notificationSeen
  // firebase_service.dart

  Stream<RepairRequest?> getLatestActiveRepairRequest(String userId) {
    return FirebaseFirestore.instance
        .collectionGroup(
            'repair_requests') // Koristi Collection Group za pretraživanje svih 'repair_requests'
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          'Published',
          'published_2', // Dodano
          'In Negotiation',
          'Job Agreed',
          'Cancelled',
          'cancelled_by_servicer',
          'waitingconfirmation',
        ])
        .orderBy('requestedDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            debugPrint(
                'RepairRequest found: ${snapshot.docs.first.data()}'); // Debug ispis
            return RepairRequest.fromMap(snapshot.docs.first.data());
          }
          debugPrint('No RepairRequest found'); // Debug ispis
          return null;
        });
  }

// Metoda za označavanje notifikacija kao viđenih
  Future<void> markNotificationsAsSeen(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('repair_requests') // Koristi Collection Group
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            'Published',
            'In Negotiation',
            'Job Agreed',
            'Cancelled',
            'cancelled_by_servicer',
            'waitingconfirmation',
          ])
          .where('notificationSeen', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'notificationSeen': true});
      }

      _logger.i('Notifications marked as seen for userId: $userId');
    } catch (e) {
      _logger.e('Error marking notifications as seen: $e');
    }
  }
}
