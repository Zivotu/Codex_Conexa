// lib/screens/servicer_dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/repair_request.dart' as rr;
import '../models/servicer.dart';
import '../services/localization_service.dart';
import '../utils/activity_codes.dart';
import 'repair_request_detail_screen.dart';
import 'servicer_settings.dart';
import 'user_locations_screen.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching maps
import '../utils/utils.dart'; // Uvoz funkcije normalizeCountryName

class ServicerDashboardScreen extends StatefulWidget {
  final String username;

  const ServicerDashboardScreen({super.key, required this.username});

  @override
  ServicerDashboardScreenState createState() => ServicerDashboardScreenState();
}

class ServicerDashboardScreenState extends State<ServicerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late String _userId;
  Servicer? _servicer;
  late TabController _tabController;

  final List<String> _selectedCategories = [];
  List<String> _licensedCategories = [];
  List<Map<String, String>> get _allCategories =>
      ActivityCodes.getAllCategories(localizationService);

  late LocalizationService localizationService;

  // Variables for the number of published jobs today
  int _publishedJobsToday = 0;

  // Variables for dynamic title
  int _waitingForConfirmationCount = 0;

  // Cached data to prevent flickering
  Future<List<rr.RepairRequest>>? _activeAdsFuture;
  Future<List<rr.RepairRequest>>? _negotiationsAdsFuture;
  Future<List<rr.RepairRequest>>? _agreedJobsFuture;
  Future<List<rr.RepairRequest>>? _completedJobsFuture;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _tabController = TabController(length: 4, vsync: this);
    localizationService = Provider.of<LocalizationService>(
      context,
      listen: false,
    );
    _fetchServicerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchServicerData() async {
    if (_userId.isEmpty) {
      debugPrint('userId nije inicijaliziran');
      return;
    }

    try {
      final servicerDoc = await FirebaseFirestore.instance
          .collection('servicers')
          .doc(_userId)
          .get();

      if (servicerDoc.exists) {
        final servicer = Servicer.fromFirestore(servicerDoc);
        final licensedCategories = List<String>.from(
          servicerDoc['selectedCategories'] ?? [],
        );
        final waitingQuery = await FirebaseFirestore.instance
            .collection('countries')
            .doc(servicer.workingCountry)
            .collection('cities')
            .doc(servicer.workingCity)
            .collection('repair_requests')
            .where('status', isEqualTo: 'waitingforconfirmation')
            .get();

        final waitingCount = waitingQuery.docs.length;

        setState(() {
          _servicer = servicer;
          _licensedCategories = licensedCategories;
          _selectedCategories.clear();
          _selectedCategories.addAll(licensedCategories);
          _waitingForConfirmationCount = waitingCount;
        });

        // Fetch published jobs count
        await _fetchPublishedJobsToday();

        // Initialize futures
        _activeAdsFuture = _fetchActiveAdsFromServer();
        _negotiationsAdsFuture = _fetchNegotiationsAdsFromServer();
        _agreedJobsFuture = _fetchAgreedJobs();
        _completedJobsFuture = _fetchCompletedJobs();
      } else {
        debugPrint('Serviser nije pronađen za korisnika: $_userId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('servicerDataNotFound') ??
                  'Podaci servisera nisu pronađeni.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizationService.translate('errorLoadingServicer') ?? 'Greška prilikom učitavanja servisera.'}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchPublishedJobsToday() async {
    if (_servicer == null) return;

    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final normalizedCountry = normalizeCountryName(_servicer!.workingCountry);
      final publishedJobsQuery = FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where('status', isEqualTo: 'Published')
          .where(
            'requestedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('requestedDate', isLessThan: Timestamp.fromDate(endOfDay));

      final publishedJobsSnapshot = await publishedJobsQuery.get();

      setState(() {
        _publishedJobsToday = publishedJobsSnapshot.docs.length;
      });
    } catch (e) {
      debugPrint('Greška prilikom brojanja objavljenih poslova danas: $e');
    }
  }

  // Fetch active ads directly from the server
  Future<List<rr.RepairRequest>> _fetchActiveAdsFromServer() async {
    if (_servicer == null) return [];

    try {
      final normalizedCountry = normalizeCountryName(_servicer!.workingCountry);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where(
        'status',
        whereIn: ['published', 'published_2', 'Published', 'Published_2'],
      ) // Added published_2
          .get(const GetOptions(source: Source.server));

      final repairRequests = querySnapshot.docs.map((doc) {
        return rr.RepairRequest.fromFirestore(doc);
      }).toList();

      // Filter out ads that contain the current userId in servicerIds
      // and filter out expired ads ("Isteklo")
      final now = DateTime.now();
      final activeAds = repairRequests.where((request) {
        bool notExpired = true;
        if (request.durationDays != null) {
          final expirationDate = request.requestedDate.add(
            Duration(days: request.durationDays!),
          );
          notExpired = expirationDate.isAfter(now);
        }
        return !request.servicerIds.contains(_userId) && notExpired;
      }).toList();

      debugPrint('Active Ads Count After Filtering: ${activeAds.length}');
      return activeAds;
    } catch (e) {
      debugPrint(
        'Greška prilikom dohvaćanja aktivnih oglasa s poslužitelja: $e',
      );
      return [];
    }
  }

  // Fetch negotiation ads directly from the server
  Future<List<rr.RepairRequest>> _fetchNegotiationsAdsFromServer() async {
    if (_servicer == null) return [];

    try {
      final normalizedCountry = normalizeCountryName(_servicer!.workingCountry);

      // Combine all relevant statuses
      final querySnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where(
        'status',
        whereIn: [
          'Published',
          'published',
          'published_2',
          'Published_2',
          'waitingforconfirmation',
        ],
      ).get(const GetOptions(source: Source.server));

      final repairRequests = querySnapshot.docs.map((doc) {
        return rr.RepairRequest.fromFirestore(doc);
      }).toList();

      // Filter ads that contain the current userId in servicerIds
      final negotiationsAds = repairRequests.where((request) {
        return request.servicerIds.contains(_userId);
      }).toList();

      // Sort ads: ones that require action (status 'waitingforconfirmation') at the top
      negotiationsAds.sort((a, b) {
        if (a.status == 'waitingforconfirmation' &&
            b.status != 'waitingforconfirmation') {
          return -1;
        } else if (a.status != 'waitingforconfirmation' &&
            b.status == 'waitingforconfirmation') {
          return 1;
        } else {
          return 0;
        }
      });

      return negotiationsAds;
    } catch (e) {
      debugPrint(
        'Greška prilikom dohvaćanja pregovaračkih oglasa s poslužitelja: $e',
      );
      return [];
    }
  }

  // Fetch agreed jobs as a Future
  Future<List<rr.RepairRequest>> _fetchAgreedJobs() async {
    if (_servicer == null) return [];

    try {
      final normalizedCountry = normalizeCountryName(_servicer!.workingCountry);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where('status', isEqualTo: 'Job Agreed')
          .get();

      final repairRequests = querySnapshot.docs.map((doc) {
        return rr.RepairRequest.fromFirestore(doc);
      }).toList();

      // Sort: jobs with closest scheduled times at the top
      repairRequests.sort((a, b) {
        DateTime? aTime = a.selectedTimeSlot?.toDate();
        DateTime? bTime = b.selectedTimeSlot?.toDate();

        if (aTime == null && bTime == null) {
          return 0;
        } else if (aTime == null) {
          return 1;
        } else if (bTime == null) {
          return -1;
        } else {
          return aTime.compareTo(bTime);
        }
      });

      // Filter out jobs whose scheduled time has passed by more than 2 hours
      DateTime now = DateTime.now();
      final validJobs = repairRequests.where((r) {
        if (r.selectedTimeSlot == null) return true;
        return r.selectedTimeSlot!
            .toDate()
            .add(const Duration(hours: 2))
            .isAfter(now);
      }).toList();

      return validJobs;
    } catch (e) {
      debugPrint('Greška prilikom dohvaćanja dogovorenih poslova: $e');
      return [];
    }
  }

  // Fetch completed jobs as a Future, uključujući istekle dogovorene poslove
  Future<List<rr.RepairRequest>> _fetchCompletedJobs() async {
    if (_servicer == null) return [];

    try {
      final normalizedCountry = normalizeCountryName(_servicer!.workingCountry);
      List<rr.RepairRequest> completedList = [];

      // Dohvati poslove sa statusom completed ili Closed
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where('status', whereIn: ['completed', 'Closed']).get();

      completedList.addAll(
        completedSnapshot.docs.map(
          (doc) => rr.RepairRequest.fromFirestore(doc),
        ),
      );

      // Dohvati "Job Agreed" poslove koji su istekli +2 sata
      final agreedSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(normalizedCountry)
          .collection('cities')
          .doc(_servicer!.workingCity)
          .collection('repair_requests')
          .where('status', isEqualTo: 'Job Agreed')
          .get();

      final now = DateTime.now();
      final expiredAgreed = agreedSnapshot.docs
          .map((doc) => rr.RepairRequest.fromFirestore(doc))
          .where((r) {
        if (r.selectedTimeSlot == null) return false;
        return r.selectedTimeSlot!
            .toDate()
            .add(const Duration(hours: 2))
            .isBefore(now);
      }).toList();

      completedList.addAll(expiredAgreed);

      // Sortiranje po datumu završetka posla ili zakazanom terminu za expiredAgreed
      completedList.sort((a, b) {
        DateTime? aTime = a.completedDate ?? a.selectedTimeSlot?.toDate();
        DateTime? bTime = b.completedDate ?? b.selectedTimeSlot?.toDate();

        if (aTime == null && bTime == null) {
          return 0;
        } else {
          return bTime!.compareTo(aTime!);
        }
      });

      return completedList;
    } catch (e) {
      debugPrint('Greška prilikom dohvaćanja dovršenih poslova: $e');
      return [];
    }
  }

  Future<void> _refreshData() async {
    await _fetchServicerData();
    setState(() {
      // Reinitialize futures
      _activeAdsFuture = _fetchActiveAdsFromServer();
      _negotiationsAdsFuture = _fetchNegotiationsAdsFromServer();
      _agreedJobsFuture = _fetchAgreedJobs();
      _completedJobsFuture = _fetchCompletedJobs();
    });
  }

  // Metoda za dohvaćanje korisničkih podataka (displayName i lastName)
  Future<Map<String, String>> _fetchUserDetails(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final displayName = data['displayName'] ??
              localizationService.translate('unknownName') ??
              'Unknown name';
          final lastName = data['lastName'] ??
              localizationService.translate('unknownSurname') ??
              'Unknown surname';
          return {'displayName': displayName, 'lastName': lastName};
        }
      }
    } catch (e) {
      debugPrint('Greška prilikom dohvaćanja korisničkih podataka: $e');
    }
    return {
      'displayName':
          localizationService.translate('unknownName') ?? 'Unknown name',
      'lastName':
          localizationService.translate('unknownSurname') ?? 'Unknown surname',
    };
  }

  Widget _buildActiveAds() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<rr.RepairRequest>>(
        future: _activeAdsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                localizationService.translate('errorLoadingAds') ??
                    'Error loading ads.',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                localizationService.translate('noActiveAds') ??
                    'No active ads available.',
              ),
            );
          }

          final activeAds = snapshot.data!;

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: activeAds.length,
            itemBuilder: (context, index) {
              final request = activeAds[index];
              return _buildRepairRequestCard(request, showUserInfo: false);
            },
          );
        },
      ),
    );
  }

  Widget _buildNegotiations() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<rr.RepairRequest>>(
        future: _negotiationsAdsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                localizationService.translate('errorLoadingNegotiations') ??
                    'Error loading negotiations.',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                localizationService.translate('noNegotiations') ??
                    'No negotiations available.',
              ),
            );
          }

          final negotiationsAds = snapshot.data!;

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: negotiationsAds.length,
            itemBuilder: (context, index) {
              final request = negotiationsAds[index];
              return _buildNegotiationCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildAgreedJobs() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<rr.RepairRequest>>(
        future: _agreedJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                localizationService.translate('errorLoadingAgreedJobs') ??
                    'Error loading agreed jobs.',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                localizationService.translate('noAgreedJobsFound') ??
                    'No agreed jobs found.',
              ),
            );
          }

          final agreedJobs = snapshot.data!;

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: agreedJobs.length,
            itemBuilder: (context, index) {
              final request = agreedJobs[index];
              return _buildAgreedJobCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<rr.RepairRequest>>(
        future: _completedJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                localizationService.translate('errorLoadingHistory') ??
                    'Error loading history.',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                localizationService.translate('noCompletedJobsFound') ??
                    'No completed jobs found.',
              ),
            );
          }

          final completedJobs = snapshot.data!;

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: completedJobs.length,
            itemBuilder: (context, index) {
              final request = completedJobs[index];
              return _buildRepairRequestCard(request, showUserInfo: true);
            },
          );
        },
      ),
    );
  }

  // Updated _buildRepairRequestCard with a top row for settlement and expiration info
  Widget _buildRepairRequestCard(
    rr.RepairRequest request, {
    bool showUserInfo = true,
  }) {
    final IconData iconData =
        ActivityCodes.categoryIcons[request.issueType] ?? Icons.build;
    final String naselje = request.naselje ??
        (localizationService.translate('unknownSettlement') ??
            'Unknown settlement');
    String remainingText = '';
    if (request.durationDays != null) {
      final expirationDate = request.requestedDate.add(
        Duration(days: request.durationDays!),
      );
      final now = DateTime.now();
      final difference = expirationDate.difference(now).inDays;
      if (difference > 0) {
        remainingText = (localizationService.translate('remainingDays') ??
                'Remaining {0} days')
            .replaceAll('{0}', difference.toString());
      } else {
        remainingText = localizationService.translate('expired') ?? 'Expired';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: request.selectedTimeSlot != null
              ? Colors.green.shade300
              : Colors.blue.shade300,
          width: 1,
        ),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with settlement chip and icon/expiration info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: request.selectedTimeSlot != null
                        ? Colors.green
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    naselje,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      iconData,
                      color: request.selectedTimeSlot != null
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                      size: 50,
                    ),
                    if (remainingText.isNotEmpty)
                      Text(
                        remainingText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showUserInfo)
              FutureBuilder<Map<String, String>>(
                future: _fetchUserDetails(request.userId),
                builder: (context, snapshot) {
                  String displayName =
                      localizationService.translate('unknownName') ??
                          'Unknown name';
                  String lastName =
                      localizationService.translate('unknownSurname') ??
                          'Unknown surname';

                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    displayName = snapshot.data!['displayName'] ?? displayName;
                    lastName = snapshot.data!['lastName'] ?? lastName;
                  }

                  return Text(
                    (localizationService.translate('userLabel') ??
                            'User: {0} {1}')
                        .replaceAll('{0}', displayName)
                        .replaceAll('{1}', lastName),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            if (showUserInfo) const SizedBox(height: 8),
            Text(
              request.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (request.imagePaths.isNotEmpty)
              Row(
                children: request.imagePaths
                    .take(3)
                    .map(
                      (imageUrl) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 70,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await _openRequestDetail(request);
                  await _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  localizationService.translate('viewDetails') ??
                      'View Details',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatSimpleDateTime(request.requestedDate),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNegotiationCard(rr.RepairRequest request) {
    final IconData iconData =
        ActivityCodes.categoryIcons[request.issueType] ?? Icons.build;
    final String naselje = request.naselje ??
        (localizationService.translate('unknownSettlement') ??
            'Unknown settlement');
    bool requiresAction = request.status == 'waitingforconfirmation';
    String remainingText = '';
    if (request.durationDays != null) {
      final expirationDate = request.requestedDate.add(
        Duration(days: request.durationDays!),
      );
      final now = DateTime.now();
      final difference = expirationDate.difference(now).inDays;
      if (difference > 0) {
        remainingText = (localizationService.translate('remainingDays') ??
                'Remaining {0} days')
            .replaceAll('{0}', difference.toString());
      } else {
        remainingText = localizationService.translate('expired') ?? 'Expired';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: requiresAction ? Colors.green.shade300 : Colors.blue.shade300,
          width: 1,
        ),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with settlement chip and icon/expiration info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: requiresAction ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    naselje,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      iconData,
                      color: requiresAction
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                      size: 50,
                    ),
                    if (remainingText.isNotEmpty)
                      Text(
                        remainingText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (request.imagePaths.isNotEmpty)
              Row(
                children: request.imagePaths
                    .take(3)
                    .map(
                      (imageUrl) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 70,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await _openRequestDetail(request);
                  await _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: requiresAction ? Colors.green : Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  localizationService.translate('viewDetails') ??
                      'View Details',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatSimpleDateTime(request.requestedDate),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreedJobCard(rr.RepairRequest request) {
    final IconData iconData =
        ActivityCodes.categoryIcons[request.issueType] ?? Icons.build;
    final String naselje = request.naselje ??
        (localizationService.translate('unknownSettlement') ??
            'Unknown settlement');
    final String userName = request.userName ??
        (localizationService.translate('unknownUser') ?? 'Unknown user');
    final String address = request.address ??
        (localizationService.translate('unknownAddress') ?? 'Unknown address');
    final String agreedDate = request.selectedTimeSlot != null
        ? _formatDateTime(request.selectedTimeSlot!.toDate())
        : (localizationService.translate('noScheduledDate') ??
            'No scheduled date');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade300, width: 1),
      ),
      elevation: 4,
      child: Stack(
        children: [
          Container(
            color: Colors.green.shade50,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Settlement chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    naselje,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (localizationService.translate('agreedJobUser') ??
                          'User: {0}')
                      .replaceAll('{0}', userName),
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  (localizationService.translate('agreedJobAddress') ??
                          'Address: {0}')
                      .replaceAll('{0}', address),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 33, 169, 71),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (localizationService.translate('agreedJobScheduled') ??
                            'Scheduled: {0}')
                        .replaceAll('{0}', agreedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (request.imagePaths.isNotEmpty)
                  Row(
                    children: request.imagePaths
                        .take(3)
                        .map(
                          (imageUrl) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 70,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _openRequestDetail(request);
                      await _refreshData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      localizationService.translate('viewDetails') ??
                          'View Details',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await _launchMap(address);
                    await _refreshData();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map, color: Colors.blue, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(iconData, color: Colors.green.shade800, size: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMap(String address) async {
    String query = Uri.encodeComponent(address);
    String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$query';
    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('mapError') ??
                'Cannot open map for this address.',
          ),
        ),
      );
    }
  }

  String _formatSimpleDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}. - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

  Future<void> _openRequestDetail(rr.RepairRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepairRequestDetailScreen(repairRequest: request),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final localizationService = context.read<LocalizationService>();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}. - ${localizationService.translate(_dayOfWeek(dateTime.weekday)) ?? _dayOfWeek(dateTime.weekday)} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}h';
  }

  String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () async {
            await _navigateToUserLocations();
            await _refreshData();
          },
          tooltip: localizationService.translate('home') ?? 'Home',
        ),
        title: Builder(
          builder: (context) {
            if (_waitingForConfirmationCount > 0) {
              String waitingMessage =
                  localizationService.translate('waitingForConfirmation') ??
                      'Waiting for your response on {0} ads';
              waitingMessage = waitingMessage.replaceAll(
                '{0}',
                _waitingForConfirmationCount.toString(),
              );
              return Text(
                waitingMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 15, 97, 9),
                ),
                overflow: TextOverflow.ellipsis,
              );
            } else {
              String publishedTitle =
                  localizationService.translate('publishedJobsToday') ??
                      'Jobs Today';
              return Text(
                '$publishedTitle: $_publishedJobsToday',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 15, 97, 9),
                ),
                overflow: TextOverflow.ellipsis,
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              await _openFilterSheet();
              await _refreshData();
            },
            tooltip: localizationService.translate('filter') ?? 'Filter',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.lightBlue, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              isScrollable: true,
              tabs: [
                Tab(
                  text: localizationService.translate('activeAds') ??
                      'Active Ads',
                  icon: const Icon(Icons.assignment),
                ),
                Tab(
                  text: localizationService.translate('agreedJobs') ??
                      'Agreed Jobs',
                  icon: const Icon(Icons.handshake),
                ),
                Tab(
                  text: localizationService.translate('negotiations') ??
                      'Negotiations',
                  icon: const Icon(Icons.message),
                ),
                Tab(
                  text: localizationService.translate('history') ?? 'History',
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Ads
          _buildActiveAds(),

          // Agreed Jobs
          _buildAgreedJobs(),

          // Negotiations
          _buildNegotiations(),

          // History
          _buildHistory(),
        ],
      ),
    );
  }

  Future<void> _navigateToServicerSettings() async {
    if (_servicer == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicerSettings(username: _servicer!.username),
      ),
    );
  }

  Future<void> _navigateToUserLocations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserLocationsScreen(username: widget.username),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSB) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    localizationService.translate('filterCategories') ??
                        'Filter Categories',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _allCategories
                        .where(
                      (category) => _licensedCategories.contains(
                        category['type'],
                      ),
                    )
                        .map((category) {
                      final isSelected = _selectedCategories.contains(
                        category['type'],
                      );
                      return ChoiceChip(
                        label: Text(category['name']!),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setStateSB(() {
                            if (selected) {
                              _selectedCategories.add(
                                category['type']!,
                              );
                            } else {
                              _selectedCategories.remove(
                                category['type']!,
                              );
                            }
                          });
                          setState(() {});
                        },
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}
