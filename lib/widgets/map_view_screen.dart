// lib/screens/map_view_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapViewScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;

  const MapViewScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  _MapViewScreenState createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  late GoogleMapController _controller;

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(widget.latitude, widget.longitude),
      zoom: 14.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address),
      ),
      body: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: {
          Marker(
            markerId: const MarkerId('adLocation'),
            position: LatLng(widget.latitude, widget.longitude),
            infoWindow: InfoWindow(title: widget.address),
          ),
        },
        onMapCreated: (GoogleMapController controller) {
          _controller = controller;
        },
        myLocationEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
