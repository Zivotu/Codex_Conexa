import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../games_screen.dart';
import 'widgets.dart';
import '../news_portal_view.dart' show ProfileAvatar; // to use ProfileAvatar class defined there

class QuizSection extends StatelessWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final String geoCountry;
  final String geoCity;
  final String geoNeighborhood;
  final FirebaseFirestore firestore;

  const QuizSection({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.geoCountry,
    required this.geoCity,
    required this.geoNeighborhood,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final DateTime today = DateTime.now();
    final String todayId =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          buildSectionHeader(
            Icons.quiz,
            loc.translate('quiz') ?? 'Kviz',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GamesScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          FutureBuilder<QuerySnapshot>(
            future: firestore
                .collection('countries')
                .doc(geoCountry.isNotEmpty ? geoCountry : countryId)
                .collection('cities')
                .doc(geoCity.isNotEmpty ? geoCity : cityId)
                .collection('locations')
                .doc(geoNeighborhood.isNotEmpty ? geoNeighborhood : locationId)
                .collection('quizz')
                .doc(todayId)
                .collection('results')
                .orderBy('score', descending: true)
                .limit(10)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children:
                      List.generate(3, (_) => buildQuizResultSkeleton()),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('error_loading_quiz_results') ??
                          'Error loading quiz results',
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('no_quiz_results_available') ??
                          'No quiz results available',
                    ),
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String userId = data['user_id'] ?? '';
                  final String userName = data['username'] ?? 'Unknown';
                  final int score = data['score'] as int? ?? 0;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: ProfileAvatar(userId: userId, radius: 25),
                      title: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${loc.translate('score') ?? 'Score'}: $score',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
