import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class CommuteMapPicker extends StatefulWidget {
  final String title;

  const CommuteMapPicker({super.key, required this.title});

  @override
  _CommuteMapPickerState createState() => _CommuteMapPickerState();
}

class _CommuteMapPickerState extends State<CommuteMapPicker> {
  GoogleMapController? _mapController;
  LatLng _pickedLocation = const LatLng(45.8150, 15.9819);
  String _address = '';
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressController.addListener(() {
      // Ako korisnik unosi adresu, ovdje možemo implementirati auto-geocode
    });
  }

  Future<void> _searchAddress() async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _pickedLocation = LatLng(loc.latitude, loc.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_pickedLocation, 13),
        );
        final address =
            await _getAddressFromLatLng(loc.latitude, loc.longitude);
        setState(() {
          _address = address;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localization.translate('cannot_find_address') ??
                'Cannot find address: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': _pickedLocation.latitude,
                  'longitude': _pickedLocation.longitude,
                  'address': _address,
                });
              },
              child: Text(
                localization.translate('confirm') ?? 'CONFIRM',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Unos adrese
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: localization.translate('enter_address') ??
                          'Enter address',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                  ),
                  onPressed: _searchAddress,
                  child: Text(
                    localization.translate('check_address') ?? 'CHECK ADDRESS',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: (latLng) async {
                setState(() {
                  _pickedLocation = latLng;
                });
                final address = await _getAddressFromLatLng(
                    latLng.latitude, latLng.longitude);
                setState(() {
                  _address = address;
                });
              },
              markers: {
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _pickedLocation,
                ),
              },
              initialCameraPosition: CameraPosition(
                target: _pickedLocation,
                zoom: 13,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _address.isEmpty
                  ? (localization.translate('choose_point') ?? 'Choose a point')
                  : '${localization.translate('selected_location') ?? 'Selected location:'} $_address',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final thoroughfare = place.thoroughfare ?? '';
        final subThoroughfare = place.subThoroughfare ?? '';
        final locality = place.locality ?? '';
        final country = place.country ?? '';
        return [thoroughfare, subThoroughfare, locality, country]
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return '';
  }
}
