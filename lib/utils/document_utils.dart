import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Fetches a list of documents from Firestore based on the provided location.
Future<List<Map<String, dynamic>>> fetchDocuments(
    String countryId, String cityId, String locationId) async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('documents')
        .get();

    return querySnapshot.docs.map((doc) {
      final document = doc.data();
      document['id'] = doc.id;
      return document;
    }).toList();
  } catch (e) {
    debugPrint('Error fetching documents: $e');
    rethrow;
  }
}

/// Adds a document to Firestore and uploads the associated image to Firebase Storage.
Future<void> addDocument(
  String countryId,
  String cityId,
  String locationId,
  String username,
  Map<String, dynamic> document,
  XFile imageFile,
) async {
  try {
    // Upload image to Cloud Storage
    final fileName =
        'documents/${username}_${DateTime.now().millisecondsSinceEpoch}.png';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);
    UploadTask uploadTask;

    if (kIsWeb) {
      uploadTask = storageRef.putData(await imageFile.readAsBytes());
    } else {
      uploadTask = storageRef.putFile(File(imageFile.path));
    }

    final taskSnapshot = await uploadTask;

    // Get the download URL of the uploaded image
    final downloadUrl = await taskSnapshot.ref.getDownloadURL();

    // Add document to Firestore
    document['username'] = username;
    document['imagePath'] = downloadUrl; // Ensure the URL is properly formatted
    final ref = FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('documents')
        .doc();
    document['id'] = ref.id;
    await ref.set(document);
  } catch (e) {
    debugPrint('Error adding document: $e');
    rethrow;
  }
}

/// Deletes a document from Firestore and the associated image from Firebase Storage.
Future<void> deleteDocument(
  String countryId,
  String cityId,
  String locationId,
  String documentId,
  String imagePath,
) async {
  try {
    // Delete image from Cloud Storage
    final storageRef = FirebaseStorage.instance.refFromURL(imagePath);
    await storageRef.delete();

    // Delete document from Firestore
    final ref = FirebaseFirestore.instance
        .collection('countries')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('locations')
        .doc(locationId)
        .collection('documents')
        .doc(documentId);
    await ref.delete();
  } catch (e) {
    debugPrint('Error deleting document: $e');
    rethrow;
  }
}
