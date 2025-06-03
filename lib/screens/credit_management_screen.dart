import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';

class CreditManagementScreen extends StatefulWidget {
  const CreditManagementScreen({super.key});

  @override
  _CreditManagementScreenState createState() => _CreditManagementScreenState();
}

class _CreditManagementScreenState extends State<CreditManagementScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Privremeno čuvamo odabir kredita za svaku lokaciju
  final Map<String, String> selectedCreditForLocation = {};

  // Formatiranje vremena
  String formatTimestamp(Timestamp? ts) {
    if (ts == null) {
      return LocalizationService.instance.translate('unknown') ?? "Unknown";
    }
    final dt = ts.toDate().toLocal();
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  // Prepravljena funkcija za jezičnu prilagodbu statusa
  String translateStatus(String status) {
    switch (status) {
      case 'active':
        return LocalizationService.instance.translate('active') ?? 'Active';
      case 'available':
        return LocalizationService.instance.translate('available') ??
            'Available';
      case 'released':
        return LocalizationService.instance.translate('released') ?? 'Released';
      case 'expired':
        return LocalizationService.instance.translate('expired') ?? 'Expired';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'available':
        return Colors.blue;
      case 'released':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  /// Dropdown za odabir kredita za određenu lokaciju
  Widget _buildCreditDropdown(String locationId, String? currentCreditId,
      List<Map<String, dynamic>> credits) {
    final uniqueCreditsMap = <String, Map<String, dynamic>>{};
    for (var credit in credits) {
      uniqueCreditsMap[credit['creditId']] = credit;
    }
    final uniqueCredits = uniqueCreditsMap.values.toList();
    final dropdownValue = (currentCreditId != null &&
            uniqueCredits
                .any((credit) => credit['creditId'] == currentCreditId))
        ? currentCreditId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          hint: Text(
            LocalizationService.instance.translate('select_credit') ??
                "Select Credit",
            style: const TextStyle(fontSize: 12),
          ),
          icon: const Icon(Icons.arrow_drop_down),
          value: dropdownValue,
          items: uniqueCredits.map((credit) {
            final status = translateStatus(credit['status'] ?? "");
            return DropdownMenuItem<String>(
              value: credit['creditId'],
              child: Row(
                children: [
                  const Icon(Icons.credit_card, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "${credit['creditId']} (${LocalizationService.instance.translate('status') ?? 'Status'}: $status)",
                    style: TextStyle(
                      fontSize: 12,
                      color: getStatusColor(credit['status'] ?? ""),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedCreditForLocation[locationId] = value ?? "";
            });
          },
        ),
        TextButton(
          onPressed: () async {
            final selected = selectedCreditForLocation[locationId];
            if (selected != null && selected.isNotEmpty) {
              await assignCredit(selected, locationId);
            }
          },
          child: Text(
            LocalizationService.instance.translate('set') ?? "Set",
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Dodjeljuje odabrani kredit lokaciji i ažurira podatke u kolekcijama credits i locations
  Future<void> assignCredit(String creditId, String locationId) async {
    try {
      // Ažuriraj kredit dokument
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('credits')
          .doc(creditId)
          .update({
        'status': 'active',
        'locationId': locationId,
      });
      // Ažuriraj lokaciju u glavnoj kolekciji
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .update({
        'creditId': creditId,
        'activationType': 'active',
      });
      // Opcionalno: Ažuriraj i u kolekciji owned_locations, ako se koristi
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('owned_locations')
          .doc(locationId)
          .update({
        'creditId': creditId,
        'activationType': 'active',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              LocalizationService.instance.translate('credit_assigned') ??
                  "Credit successfully assigned"),
        ),
      );
    } catch (e) {
      debugPrint("Error assigning credit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.instance
                  .translate('credit_assignment_error') ??
              "Error assigning credit"),
        ),
      );
    }
  }

  /// Widget za prikaz slike lokacije
  Widget _buildLocationImage(
      String locationId, List<Map<String, dynamic>> locations) {
    final loc = locations.firstWhere(
      (loc) => loc['locationId'] == locationId,
      orElse: () => <String, dynamic>{},
    );
    String imagePath = "";
    if (loc.isNotEmpty) {
      imagePath = loc['imagePath'] ?? "";
    }
    if (imagePath.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: imagePath.startsWith("http")
            ? NetworkImage(imagePath)
            : AssetImage(imagePath) as ImageProvider,
        radius: 24,
      );
    }
    return const CircleAvatar(radius: 24, child: Icon(Icons.location_on));
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            localization.translate('credit_management') ?? "Credit Management"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('credits')
            .snapshots(),
        builder: (context, creditSnapshot) {
          if (creditSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final creditsData = creditSnapshot.data!.docs.map((doc) {
            return {
              'creditId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            };
          }).toList();

          final filteredCredits =
              creditsData.where((c) => c['status'] != 'expired').toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('locations')
                .where('ownedBy', isEqualTo: userId)
                .snapshots(),
            builder: (context, locationSnapshot) {
              if (locationSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final locationsData = locationSnapshot.data!.docs.map((doc) {
                return {
                  'locationId': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                };
              }).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('credits') ?? "Credits:",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      filteredCredits.isEmpty
                          ? Text(
                              localization.translate('no_credits_available') ??
                                  "No credits available.\nCredits are created when you purchase (or change) your subscription.",
                              style: const TextStyle(fontSize: 16),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredCredits.length,
                              itemBuilder: (context, index) {
                                final credit = filteredCredits[index];
                                final expiry = formatTimestamp(
                                    credit['activeUntil'] as Timestamp?);
                                String locName =
                                    localization.translate('not_assigned') ??
                                        "Not assigned";
                                if (credit['locationId'] != null &&
                                    (credit['locationId'] as String)
                                        .isNotEmpty) {
                                  final loc = locationsData.firstWhere(
                                    (loc) =>
                                        loc['locationId'] ==
                                        credit['locationId'],
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (loc.isNotEmpty && loc['name'] != null) {
                                    locName = loc['name'];
                                  }
                                }
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    leading: const Icon(Icons.credit_card,
                                        color: Colors.teal),
                                    title: Text(
                                      "${localization.translate('credit_id') ?? 'Credit ID:'} ${credit['creditId']}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      "${localization.translate('status') ?? 'Status:'} ${translateStatus(credit['status'] ?? "")}\n"
                                      "${localization.translate('expires') ?? 'Expires:'} $expiry\n"
                                      "${localization.translate('assigned') ?? 'Assigned:'} $locName",
                                    ),
                                    trailing: (credit['locationId'] != null &&
                                            (credit['locationId'] as String)
                                                .isNotEmpty)
                                        ? _buildLocationImage(
                                            credit['locationId'], locationsData)
                                        : null,
                                  ),
                                );
                              },
                            ),
                      const Divider(height: 32),
                      Text(
                        localization.translate('locations') ?? "Locations:",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      locationsData.isEmpty
                          ? Text(
                              localization.translate('no_locations_created') ??
                                  "No locations created.",
                              style: const TextStyle(fontSize: 16),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: locationsData.length,
                              itemBuilder: (context, index) {
                                final loc = locationsData[index];
                                final imagePath = loc['imagePath'] ?? "";
                                Widget locationImage = imagePath.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage:
                                            imagePath.startsWith("http")
                                                ? NetworkImage(imagePath)
                                                : AssetImage(imagePath)
                                                    as ImageProvider,
                                        radius: 24,
                                      )
                                    : const CircleAvatar(
                                        radius: 24,
                                        child: Icon(Icons.location_on));
                                final currentCreditId = loc['creditId'] ?? "";
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          leading: locationImage,
                                          title: Text(
                                            loc['name'] ??
                                                (localization.translate(
                                                        'unknown_name') ??
                                                    "Unknown Name"),
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            currentCreditId.isNotEmpty
                                                ? "${localization.translate('credit_assigned') ?? 'Credit assigned:'} $currentCreditId"
                                                : (localization.translate(
                                                        'credit_not_assigned') ??
                                                    "Credit not assigned"),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                        ),
                                        _buildCreditDropdown(loc['locationId'],
                                            currentCreditId, filteredCredits),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
