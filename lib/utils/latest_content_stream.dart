import 'package:cloud_firestore/cloud_firestore.dart';

Stream<Map<String, dynamic>> fetchLatestContent(String locationName) {
  return FirebaseFirestore.instance
      .collection('locations/$locationName/chats')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .asyncMap((chatSnapshot) async {
    final latestChatMessage =
        chatSnapshot.docs.isNotEmpty ? chatSnapshot.docs.first.data() : {};

    final latestDocumentsSnapshot = await FirebaseFirestore.instance
        .collection('locations/$locationName/documents')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    final latestBulletinBoardSnapshot = await FirebaseFirestore.instance
        .collection('locations/$locationName/bulletin_board')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    final latestBlogsSnapshot = await FirebaseFirestore.instance
        .collection('locations/$locationName/blogs')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    String latestChatText = '';
    String latestDocumentText = '';
    String latestBulletinText = '';
    String latestBlogText = '';

    if (latestChatMessage.isNotEmpty) {
      latestChatText =
          '${latestChatMessage.containsKey('text') ? latestChatMessage['text'] : 'No text available'}';
    }

    if (latestDocumentsSnapshot.docs.isNotEmpty) {
      final documentData = latestDocumentsSnapshot.docs.first.data();
      latestDocumentText =
          '${documentData.containsKey('title') ? documentData['title'] : 'No title available'}';
    }

    if (latestBulletinBoardSnapshot.docs.isNotEmpty) {
      final bulletinData = latestBulletinBoardSnapshot.docs.first.data();
      latestBulletinText =
          '${bulletinData.containsKey('title') ? bulletinData['title'] : 'No title available'}';
    }

    if (latestBlogsSnapshot.docs.isNotEmpty) {
      final blogData = latestBlogsSnapshot.docs.first.data();
      latestBlogText =
          '${blogData.containsKey('title') ? blogData['title'] : 'No title available'}';
    }

    return {
      'latestChatText': latestChatText,
      'latestDocumentText': latestDocumentText,
      'latestBulletinText': latestBulletinText,
      'latestBlogText': latestBlogText,
    };
  });
}
