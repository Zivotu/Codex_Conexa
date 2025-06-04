import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../document_preview_screen.dart';
import '../documents_screen.dart';
import 'widgets.dart';

class DocumentsSection extends StatelessWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final String geoCountry;
  final String geoCity;
  final String geoNeighborhood;
  final FirebaseFirestore firestore;
  final Future<void> Function(Map<String, dynamic>) openDocument;

  const DocumentsSection({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.geoCountry,
    required this.geoCity,
    required this.geoNeighborhood,
    required this.firestore,
    required this.openDocument,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.orange[50],
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          buildSectionHeader(
            Icons.description,
            loc.translate('documents') ?? 'Documents',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentsScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
            headerColor: Colors.grey,
          ),
          FutureBuilder<QuerySnapshot>(
            future: firestore
                .collection('countries')
                .doc(geoCountry.isNotEmpty ? geoCountry : countryId)
                .collection('cities')
                .doc(geoCity.isNotEmpty ? geoCity : cityId)
                .collection('locations')
                .doc(geoNeighborhood.isNotEmpty ? geoNeighborhood : locationId)
                .collection('documents')
                .orderBy('createdAt', descending: true)
                .limit(2)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children:
                      List.generate(2, (_) => buildListTileSkeleton()),
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
                  final String itemTitle = data['title'] as String? ?? '';
                  final Timestamp ts = (data['createdAt'] is Timestamp)
                      ? data['createdAt'] as Timestamp
                      : Timestamp.now();
                  final DateTime createdAt = ts.toDate();
                  return GestureDetector(
                    onTap: () {
                      final docMap = {'id': doc.id, ...data};
                      openDocument(docMap);
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
