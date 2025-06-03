// lib/screens/location_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LocationManagementScreen extends StatelessWidget {
  const LocationManagementScreen({super.key});

  Future<void> _deactivateLocation(String id) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Referenca na dokument u kolekciji 'locations'
    DocumentReference locationRef =
        FirebaseFirestore.instance.collection('locations').doc(id);
    // Referenca na dokument u kolekciji 'owned_locations'
    DocumentReference ownedLocationRef =
        FirebaseFirestore.instance.collection('owned_locations').doc(id);

    // Postavljamo status na "inactive" i brišemo datum aktivnosti
    batch.update(locationRef, {
      "activationType": "inactive",
      "activeUntil": null,
    });
    batch.update(ownedLocationRef, {
      "activationType": "inactive",
      "activeUntil": null,
    });

    try {
      await batch.commit();
      debugPrint("Batch update succeeded for document id: $id");
    } catch (e) {
      debugPrint("Error during batch commit for document id $id: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Niste prijavljeni.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Moje lokacije"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('locations')
            .where('ownedBy', isEqualTo: user.uid)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("Još nemate lokacija."));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              // Koristimo stvarni ID dokumenta umjesto polja unutar podataka
              final id = docs[i].id;
              final data = docs[i].data() as Map<String, dynamic>;
              // Status se temelji na polju activationType
              final status = data['activationType'] ?? "??";
              final name = data['name'] ?? "??";

              return ListTile(
                title: Text(name),
                subtitle: Text("Status: $status"),
                trailing: (status == "active")
                    ? TextButton(
                        onPressed: () {
                          _deactivateLocation(id);
                        },
                        child: const Text("Deaktiviraj"),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
