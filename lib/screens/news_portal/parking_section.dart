import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parking_request.dart';
import '../../services/localization_service.dart';
import '../parking_community_screen.dart';
import 'widgets.dart';

class ParkingSection extends StatelessWidget {
  final List<ParkingRequest> parkingPreview;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final bool locationAdmin;
  final String Function(DateTime, String) formatDateTime;

  const ParkingSection({
    super.key,
    required this.parkingPreview,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationAdmin,
    required this.formatDateTime,
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
            Icons.local_parking,
            loc.translate('parking') ?? 'Parking',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParkingCommunityScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                    locationAdmin: locationAdmin,
                  ),
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: parkingPreview.isEmpty
                ? Text(
                    loc.translate('no_active_parking_requests') ??
                        'Trenutno nema aktivnih (pending) parking zahtjeva.',
                  )
                : Column(
                    children: parkingPreview
                        .map((req) => GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ParkingCommunityScreen(
                                      username: username,
                                      countryId: countryId,
                                      cityId: cityId,
                                      locationId: locationId,
                                      locationAdmin: locationAdmin,
                                    ),
                                  ),
                                );
                              },
                              child: _ParkingRequestPreview(
                                req: req,
                                loc: loc,
                                formatDateTime: formatDateTime,
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ParkingRequestPreview extends StatelessWidget {
  final ParkingRequest req;
  final LocalizationService loc;
  final String Function(DateTime, String) formatDateTime;

  const _ParkingRequestPreview({
    required this.req,
    required this.loc,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final String timeString =
        '${formatDateTime(req.startDate, req.startTime)} - ${formatDateTime(req.endDate, req.endTime)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${loc.translate('parking_request_for') ?? 'Zahtjev za'} ${req.numberOfSpots} ${loc.translate('spot_s') ?? 'mjesto(a)'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    timeString,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (req.message.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      req.message,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
