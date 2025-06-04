import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../construction_screen.dart';
import 'widgets.dart';

class BukaSection extends StatelessWidget {
  final List<Map<String, dynamic>> works;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const BukaSection({
    super.key,
    required this.works,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
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
            Icons.construction,
            loc.translate('noise') ?? 'Buka',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConstructionScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          works.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      loc.translate('no_active_works') ?? 'Trenutno nema radova.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: works.length,
                  itemBuilder: (context, index) {
                    final work = works[index];
                    final String description = work['description'] ?? '';
                    final String details = work['details'] ?? '';
                    final DateTime startDate = DateTime.parse(work['startDate']);
                    final DateTime endDate = DateTime.parse(work['endDate']);
                    final dateFormat = DateFormat('dd.MM.yyyy');
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              description,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 5),
                            Text(details),
                            const SizedBox(height: 5),
                            Text(
                              '${loc.translate('date') ?? 'Date'}: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
