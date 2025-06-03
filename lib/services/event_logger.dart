// lib/services/event_logger.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class EventLogger {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> logEvent(String eventType, Map<String, dynamic> metadata) async {
    try {
      await _db.collection('events').add({
        'type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      print('Error logging event: $e');
    }
  }
}
