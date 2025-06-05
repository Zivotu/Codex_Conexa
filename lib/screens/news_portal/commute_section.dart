
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ride_model.dart';
import '../../services/localization_service.dart';
import '../../commute_screens/commute_ride_detail_screen.dart';
import '../../commute_screens/commute_rides_list_screen.dart';
import 'widgets.dart';
import '../../commute_widgets/commute_preview_card.dart';

class CommuteSection extends StatelessWidget {
  final List<Ride> commutePreview;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final FirebaseAuth? auth;
  final String Function(DateTime, LocalizationService) formatTimeAgo;

  const CommuteSection({
    super.key,
    required this.commutePreview,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.auth,
    required this.formatTimeAgo,
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
            Icons.directions_car,
            loc.translate('commute') ?? 'Zajednički prijevoz',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommuteRidesListScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          commutePreview.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    loc.translate('no_offered_rides') ?? 'Trenutno nema ponuđenih vožnji.',
                  ),
                )
              : Column(
                  children: commutePreview
                      .map(
                        (ride) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommuteRideDetailScreen(
                                  rideId: ride.rideId,
                                  userId: auth?.currentUser?.uid ?? '',
                                ),
                              ),
                            );
                          },
                          child: CommutePreviewCard(
                            ride: ride,
                            loc: loc,
                            formatTimeAgo: formatTimeAgo,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }
}

