import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../commute_screens/commute_ride_detail_screen.dart';
import '../models/ride_model.dart';
import '../services/localization_service.dart';
import '../services/location_service.dart';

class CommutePreviewCard extends StatelessWidget {
  final Ride ride;
  final LocalizationService loc;
  final String Function(DateTime, LocalizationService) formatTimeAgo;

  const CommutePreviewCard({
    super.key,
    required this.ride,
    required this.loc,
    required this.formatTimeAgo,
  });

  String _buildStaticMapUrl() {
    final apiKey = LocationService().apiKey;
    final start = '${ride.startLocation.latitude},${ride.startLocation.longitude}';
    final end = '${ride.endLocation.latitude},${ride.endLocation.longitude}';
    final buffer = StringBuffer(start);
    for (final gp in ride.route) {
      buffer.write('|${gp.latitude},${gp.longitude}');
    }
    buffer.write('|$end');
    final path = buffer.toString();
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?size=600x300&markers=color:green|$start&markers=color:red|$end'
        '&path=color:0x0000ff|weight:4|$path&key=$apiKey';
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommuteRideDetailScreen(
          rideId: ride.rideId,
          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = ride.createdAt.toDate();
    final mapUrl = _buildStaticMapUrl();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${loc.translate('driver') ?? 'Driver'}: ${ride.driverName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${loc.translate('start_address') ?? 'Polazište'}: ${ride.startAddress}'),
            Text('${loc.translate('destination') ?? 'Odredište'}: ${ride.endAddress}'),
            const SizedBox(height: 4),
            Text(
              '${loc.translate('published') ?? 'Objavljeno'}: ${formatTimeAgo(createdAt, loc)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openDetail(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  mapUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
