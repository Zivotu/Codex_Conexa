import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  // Dobivanje broja novih stavki u bilo kojoj kolekciji, koristeći "createdAt" polje.
  Future<int> getNewItemsCount(
      String locationId, String collection, Duration timeFrame) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .collection(collection)
        .where('createdAt',
            isGreaterThan: Timestamp.now().toDate().subtract(timeFrame))
        .get();

    return querySnapshot.size;
  }

  // Specifične metode koje koriste generičku metodu iznad za različite kolekcije
  Future<int> getNewMessagesCount(String locationId) {
    return getNewItemsCount(locationId, 'chats', const Duration(hours: 2));
  }

  Future<int> getNewDocumentsCount(String locationId) {
    return getNewItemsCount(locationId, 'documents', const Duration(hours: 24));
  }

  Future<int> getNewBulletinsCount(String locationId) {
    return getNewItemsCount(
        locationId, 'bulletin_board', const Duration(hours: 12));
  }

  Future<int> getNewBlogsCount(String locationId) {
    return getNewItemsCount(locationId, 'blogs', const Duration(hours: 12));
  }

  // Metoda za dobivanje zadnje stavke (najnovije poruke ili naslova)
  Future<String?> getLatestItemContent(
      String locationId, String collection, String contentField) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first[contentField] as String?;
    } else {
      return null;
    }
  }

  Future<String?> getLatestMessage(String locationId) {
    return getLatestItemContent(locationId, 'chats', 'text');
  }

  Future<String?> getLatestDocumentTitle(String locationId) {
    return getLatestItemContent(locationId, 'documents', 'title');
  }

  Future<String?> getLatestBulletinTitle(String locationId) {
    return getLatestItemContent(locationId, 'bulletin_board', 'title');
  }

  Future<String?> getLatestBlogTitle(String locationId) {
    return getLatestItemContent(locationId, 'blogs', 'title');
  }
}
