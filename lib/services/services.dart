import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; // Dodajemo logger

final Logger _logger = Logger(); // Inicijalizujemo logger

/// Resetira broj novih postova za zadanu kategoriju korisnika
Future<void> resetNewPostsCount(String username, String categoryField) async {
  try {
    // Dohvati dokument korisnika iz Firestore baze podataka
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(username)
        .get();

    if (userDoc.exists) {
      // Ažuriraj polje 'categoryVisits' s trenutnim vremenskim oznakom i postavi 'newPostsCount' na 0
      await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .update({
        'categoryVisits.$categoryField': FieldValue.serverTimestamp(),
        'newPostsCount.$categoryField': 0,
      });
      _logger.d(
          'New posts count reset for $categoryField'); // Zamenjujemo print sa loggerom
    } else {
      _logger
          .w('User document does not exist.'); // Zamenjujemo print sa loggerom
    }
  } catch (e) {
    _logger.e(
        'Error resetting new posts count: $e'); // Zamenjujemo print sa loggerom
  }
}

/// Navigira na zadanu kategoriju u aplikaciji
Future<void> navigateToCategory(BuildContext context,
    {required String route,
    required String categoryField,
    required String username,
    required String locationName}) async {
  // Resetiraj broj novih postova za zadanu kategoriju
  await resetNewPostsCount(username, categoryField);

  // Provera da li je widget još uvek montiran pre korišćenja Navigator-a
  if (context.mounted) {
    // Navigiraj na zadanu rutu
    Navigator.pushNamed(context, route, arguments: {
      'username': username,
      'locationName': locationName,
    });
  }
}
