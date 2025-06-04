import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bulletin.dart';
import '../../services/localization_service.dart';
import '../bulletin_board_screen.dart';
import '../full_screen_bulletin.dart';
import 'widgets.dart';

class BulletinBoardSection extends StatelessWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final String geoCountry;
  final String geoCity;
  final String geoNeighborhood;
  final FirebaseFirestore firestore;

  const BulletinBoardSection({
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          buildSectionHeader(
            Icons.announcement,
            loc.translate('bulletin_board') ?? 'Bulletin Board',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BulletinBoardScreen(
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
                .collection('bulletin_board')
                .orderBy('createdAt', descending: true)
                .limit(2)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('error_loading_data') ?? 'Error loading data.',
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('no_data_available') ?? 'No data available.',
                    ),
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List<dynamic> imagePaths = data['imagePaths'] ?? <dynamic>[];
                  String firstImage = 'assets/images/bulletin.png';
                  if (imagePaths.isNotEmpty && imagePaths[0] is String) {
                    firstImage = imagePaths[0];
                  }
                  final String itemTitle = data['title'] as String? ?? '';
                  final Timestamp ts = (data['createdAt'] is Timestamp)
                      ? data['createdAt'] as Timestamp
                      : Timestamp.now();
                  final DateTime createdAt = ts.toDate();
                  final Bulletin bullet = Bulletin.fromMap(data, doc.id);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenBulletin(
                            bulletin: bullet,
                            username: username,
                            countryId: countryId,
                            cityId: cityId,
                            locationId: locationId,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file, size: 48, color: Colors.grey),
                        title: Text(
                          itemTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          formatTimeAgo(createdAt, loc),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
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
