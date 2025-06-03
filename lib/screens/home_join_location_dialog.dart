import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinLocationDialog extends StatefulWidget {
  final Function onJoinSuccess;

  const JoinLocationDialog({super.key, required this.onJoinSuccess});

  @override
  JoinLocationDialogState createState() => JoinLocationDialogState();
}

class JoinLocationDialogState extends State<JoinLocationDialog> {
  final TextEditingController _linkController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Future<bool>? _joinLocationFuture;

  Future<bool> _addUserToLocation(
      String locationId, Map<String, dynamic> locationData) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);

    final userDoc = await userRef.get();
    final userLocations =
        List<Map<String, dynamic>>.from(userDoc['locations'] ?? []);
    final locationExists =
        userLocations.any((location) => location['locationId'] == locationId);

    if (locationExists) {
      await userRef.update({
        'locations': userLocations.map((location) {
          if (location['locationId'] == locationId) {
            location['status'] = 'joined';
            location['joinedAt'] = Timestamp.now();
          }
          return location;
        }).toList(),
      });

      await FirebaseFirestore.instance
          .collection('countries')
          .doc(locationData['countryId'])
          .collection('cities')
          .doc(locationData['cityId'])
          .collection('locations')
          .doc(locationId)
          .update({
        'userIds': FieldValue.arrayUnion([currentUser!.uid])
      });

      return true;
    } else {
      await userRef.update({
        'locations': FieldValue.arrayUnion([
          {
            'locationId': locationId,
            'locationName': locationData['name'],
            'countryId': locationData['countryId'],
            'cityId': locationData['cityId'],
            'status': 'joined',
            'joinedAt': Timestamp.now(),
          }
        ]),
      });

      await FirebaseFirestore.instance
          .collection('countries')
          .doc(locationData['countryId'])
          .collection('cities')
          .doc(locationData['cityId'])
          .collection('locations')
          .doc(locationId)
          .update({
        'userIds': FieldValue.arrayUnion([currentUser!.uid]),
      });

      return true;
    }
  }

  Future<bool> _joinLocation(String link) async {
    final globalLocationDocs = await FirebaseFirestore.instance
        .collection('all_locations')
        .where('link', isEqualTo: link)
        .get();

    if (globalLocationDocs.docs.isNotEmpty) {
      final locationDoc = globalLocationDocs.docs.first;
      final locationId = locationDoc.id;
      final locationData = locationDoc.data();

      return await _addUserToLocation(locationId, locationData);
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _joinLocationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            title: Text('Prijavi se u lokaciju'),
            content: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return AlertDialog(
            title: const Text('Prijavi se u lokaciju'),
            content: Text('Greška pri prijavi u lokaciju: ${snapshot.error}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('OK'),
              ),
            ],
          );
        } else if (snapshot.hasData && snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Drago nam je da ste se vratili!')),
            );
            widget.onJoinSuccess();
            Navigator.of(context).pop(true);
          });
          return const SizedBox.shrink();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lokacija nije pronađena')),
            );
            Navigator.of(context).pop(false);
          });
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget buildInput(BuildContext context) {
    return AlertDialog(
      title: const Text('Prijavi se u lokaciju'),
      content: TextField(
        controller: _linkController,
        decoration: const InputDecoration(hintText: 'Unesite link lokacije'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ODUSTANI'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _joinLocationFuture = _joinLocation(_linkController.text.trim());
            });
          },
          child: const Text('PRIJAVI SE'),
        ),
      ],
    );
  }
}
