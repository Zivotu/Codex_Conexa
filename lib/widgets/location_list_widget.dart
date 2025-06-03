import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/location_details_screen.dart'; // Dodajte ovaj import ako je ekran definisan u drugoj datoteci

class LocationListWidget extends StatelessWidget {
  final String username;

  const LocationListWidget({
    super.key,
    required this.username,
  });

  Future<List<Map<String, dynamic>>> _fetchLocations() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_locations')
        .doc(username)
        .collection('locations')
        .where('status', isEqualTo: 'joined')
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    return snapshot.docs
        .map((doc) => doc.data())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Locations'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLocations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading locations'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No locations found'));
          }

          final locations = snapshot.data!;

          if (locations.isEmpty) {
            return const Center(child: Text('No locations available'));
          }

          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return ListTile(
                title: Text(location['name'] ?? 'Unnamed Location'),
                subtitle: Text(location['address'] ?? 'No address available'),
                onTap: () {
                  _navigateToLocationDetails(context, location);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToLocationDetails(
      BuildContext context, Map<String, dynamic> location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailsScreen(
          countryId: location['countryId'] ?? '',
          cityId: location['cityId'] ?? '',
          locationId: location['locationId'] ?? '',
          username: username,
          displayName: location['name'] ?? 'Unnamed Location',
          isFunnyMode: false,
          locationAdmin: false,
        ),
      ),
    );
  }
}
