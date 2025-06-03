// lib/screens/slot_management_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';

class SlotManagementScreen extends StatefulWidget {
  const SlotManagementScreen({super.key});

  @override
  _SlotManagementScreenState createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends State<SlotManagementScreen> {
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _fetchLocations() async {
    setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_locations')
          .get(); // Dohvat svih dokumenata

      List<Map<String, dynamic>> fetchedLocations = snapshot.docs
          .map((doc) {
            final data = doc.data();
            // Ako postoji polje 'deleted' i postavljeno je na true, preskoči dokument
            if (data.containsKey('deleted') && data['deleted'] == true) {
              return null;
            }
            return {
              'locationId': doc.id,
              ...data,
            };
          })
          .where((doc) => doc != null)
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        locations = fetchedLocations;
      });
    } catch (e) {
      debugPrint("Error fetching locations: $e");
    }
    setState(() => isLoading = false);
  }

  // Dodana logika za 'manualdeactivated'
  Future<void> _toggleActivation(String locationId, bool activate) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    DocumentReference ownedLocationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('owned_locations')
        .doc(locationId);

    DocumentReference locationRef =
        FirebaseFirestore.instance.collection('locations').doc(locationId);

    String newStatus = activate ? 'active' : 'manualdeactivated';

    batch.update(ownedLocationRef, {'activationType': newStatus});
    batch.update(locationRef, {'activationType': newStatus});

    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activate
              ? localizationService.translate('locationActivated')
              : localizationService.translate('locationDeactivated')),
          backgroundColor: Colors.blueAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchLocations();
    } catch (e) {
      debugPrint("Error toggling activation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(localizationService.translate('activationChangeError'))),
      );
    }
  }

  String formatTimestamp(Timestamp? ts) {
    if (ts == null) {
      return Provider.of<LocalizationService>(context, listen: false)
          .translate('unknown');
    }
    DateTime dt = ts.toDate().toLocal();
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    int maxSlots = subscriptionService.slotCount;
    int activeCount =
        locations.where((loc) => loc['activationType'] == 'active').length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(localizationService.translate('slotManagement')),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: _fetchLocations,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    maxSlots == 0
                        ? Text(
                            localizationService
                                .translate('activeSubscriptionRequired'),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red),
                          )
                        : Text(
                            "${localizationService.translate('slots')}: ${localizationService.translate('active')} $activeCount ${localizationService.translate('of')} $maxSlots",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: locations.length,
                      itemBuilder: (context, index) {
                        final loc = locations[index];
                        final bool isActive =
                            (loc['activationType'] ?? 'inactive') == 'active' ||
                                (loc['activationType'] ?? 'inactive') ==
                                    'trial';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              loc['name'] ??
                                  localizationService
                                      .translate('unknownLocation'),
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${localizationService.translate('status')}: ${loc['activationType']}\n${loc['activeUntil'] != null ? "${localizationService.translate('activeUntil')}: ${formatTimestamp(loc['activeUntil'])}" : ""}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: Switch(
                              value: isActive,
                              activeColor: Colors.blueAccent,
                              onChanged: (bool value) async {
                                if (value && maxSlots == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(localizationService
                                          .translate('subscriptionRequired')),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                if (value && activeCount >= maxSlots) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(localizationService
                                          .translate('noFreeSlots')),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                await _toggleActivation(
                                    loc['locationId'], value);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
