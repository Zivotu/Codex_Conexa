import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/ride_model.dart';
import '../../services/localization_service.dart';
import '../commute_screens/commute_ride_detail_screen.dart';
import '../commute_screens/commute_rides_list_screen.dart';
import 'widgets.dart';

class CommuteSection extends StatelessWidget {
  final List<Ride> commutePreview;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final FirebaseAuth? auth;
  final Map<String, Completer<GoogleMapController>> smallMapControllers;
  final String Function(DateTime, LocalizationService) formatTimeAgo;

  const CommuteSection({
    super.key,
    required this.commutePreview,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.auth,
    required this.smallMapControllers,
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
                          child: _CommutePreviewCard(
                            ride: ride,
                            loc: loc,
                            formatTimeAgo: formatTimeAgo,
                            mapControllers: smallMapControllers,
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

class _CommutePreviewCard extends StatelessWidget {
  final Ride ride;
  final LocalizationService loc;
  final String Function(DateTime, LocalizationService) formatTimeAgo;
  final Map<String, Completer<GoogleMapController>> mapControllers;

  const _CommutePreviewCard({
    required this.ride,
    required this.loc,
    required this.formatTimeAgo,
    required this.mapControllers,
  });

  @override
  Widget build(BuildContext context) {
    final String driverName = ride.driverName;
    final DateTime createdAt = ride.createdAt.toDate();
    final double startLat = ride.startLocation.latitude;
    final double startLng = ride.startLocation.longitude;
    final double endLat = ride.endLocation.latitude;
    final double endLng = ride.endLocation.longitude;
    final String rideId = ride.rideId;

    List<LatLng> routeLatLng = [];
    for (var gp in ride.route) {
      routeLatLng.add(LatLng(gp.latitude, gp.longitude));
    }
    mapControllers.putIfAbsent(rideId, () => Completer<GoogleMapController>());

    final startMarker = Marker(
      markerId: MarkerId('start_$rideId'),
      position: LatLng(startLat, startLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
    final endMarker = Marker(
      markerId: MarkerId('end_$rideId'),
      position: LatLng(endLat, endLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    final markers = {startMarker, endMarker};

    final Set<Polyline> polylines = {};
    if (routeLatLng.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('ride_$rideId'),
          color: Colors.blue,
          width: 4,
          points: routeLatLng,
        ),
      );
    }

    final List<LatLng> latLngList = [
      LatLng(startLat, startLng),
      LatLng(endLat, endLng),
      ...routeLatLng
    ];
    LatLngBounds? bounds;
    if (latLngList.isNotEmpty) {
      double minLat = latLngList.first.latitude;
      double maxLat = latLngList.first.latitude;
      double minLng = latLngList.first.longitude;
      double maxLng = latLngList.first.longitude;
      for (var ll in latLngList) {
        if (ll.latitude < minLat) minLat = ll.latitude;
        if (ll.latitude > maxLat) maxLat = ll.latitude;
        if (ll.longitude < minLng) minLng = ll.longitude;
        if (ll.longitude > maxLng) maxLng = ll.longitude;
      }
      bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
    }

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
              '${loc.translate('driver') ?? 'Driver'}: $driverName',
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
            SizedBox(
              height: 120,
              child: GoogleMap(
                onMapCreated: (controller) async {
                  if (!mapControllers[rideId]!.isCompleted) {
                    mapControllers[rideId]!.complete(controller);
                  }
                  if (bounds != null) {
                    await Future.delayed(const Duration(milliseconds: 300));
                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(bounds, 50),
                    );
                  }
                },
                markers: markers,
                polylines: polylines,
                initialCameraPosition: CameraPosition(
                  target: LatLng(startLat, startLng),
                  zoom: 4.5,
                ),
                zoomControlsEnabled: false,
                myLocationEnabled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
