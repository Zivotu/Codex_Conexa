// lib/screens/parking_community_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/parking_service.dart';
import '../services/user_service.dart';
import '../services/parking_schedule_service.dart';
import '../services/localization_service.dart';

import '../models/parking_slot.dart';
import '../models/parking_request.dart';

import 'months_days_screen.dart';
import 'define_availability_screen.dart';
import 'request_parking_screen.dart';
import 'manage_requests_screen.dart';
import 'join_parking_dialog.dart';
import 'user_locations_screen.dart';
import 'edit_parking_slots_screen.dart';

class ParkingCommunityScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;
  final bool locationAdmin;

  const ParkingCommunityScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
    required this.locationAdmin,
  });

  @override
  _ParkingCommunityScreenState createState() => _ParkingCommunityScreenState();
}

class _ParkingCommunityScreenState extends State<ParkingCommunityScreen> {
  final ParkingService _parkingService = ParkingService();
  final UserService _userService = UserService();
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isJoined = false;
  List<ParkingSlot> _userParkingSlots = [];
  Map<String, dynamic>? _currentUserData;
  late String currentUserId;
  Timer? _refreshTimer; // Timer for periodic refresh

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      _initScreen();
    }
    // Refresh every minute to re-evaluate expired requests
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initScreen() async {
    await _checkIfUserJoined();
    await _loadCurrentUserData();
    setState(() {});
  }

  /// Check if the current user has joined the community
  Future<void> _checkIfUserJoined() async {
    bool joined = await _parkingService.isUserJoined(
      userId: currentUserId,
      countryId: widget.countryId,
      cityId: widget.cityId,
      locationId: widget.locationId,
    );

    if (joined) {
      _userParkingSlots = await _parkingScheduleService.getUserParkingSlots(
        userId: currentUserId,
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );
      _isJoined = true;
    } else {
      _isJoined = false;
    }
  }

  /// Load current user data
  Future<void> _loadCurrentUserData() async {
    try {
      _currentUserData = await _userService.getUserDocumentById(currentUserId);
    } catch (e) {
      debugPrint("Error loading user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('userDataLoadError') ??
                'Error loading user data: $e',
          ),
        ),
      );
    }
  }

  /// Show dialog to join the community
  void _showJoinParkingDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return JoinParkingDialog(
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          onJoinSuccess: () async {
            Navigator.of(context).pop();
            await _checkIfUserJoined();
            await _loadCurrentUserData();
            setState(() {});
          },
        );
      },
    );
  }

  /// Approve a parking request (supports multiple slot assignments)
  Future<void> _approveRequest(ParkingRequest request) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('userNotLoggedIn') ??
                'User is not logged in.',
          ),
        ),
      );
      return;
    }

    String currentUserId = currentUser.uid;

    try {
      List<String> alreadyAssignedSlots =
          await _parkingScheduleService.getAssignedSpots(
        countryId: request.countryId,
        cityId: request.cityId,
        locationId: request.locationId,
        requestId: request.requestId,
      );

      List<ParkingSlot> userParkingSlots =
          await _parkingScheduleService.getUserParkingSlots(
        userId: currentUserId,
        countryId: request.countryId,
        cityId: request.cityId,
        locationId: widget.locationId,
      );

      if (userParkingSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocalizationService>(context, listen: false)
                      .translate('noParkingSlotsAvailable') ??
                  'No parking slots available.',
            ),
          ),
        );
        return;
      }

      List<String> selectedSlotIds = [];
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  Provider.of<LocalizationService>(context, listen: false)
                          .translate('assignParkingSlots') ??
                      'Assign parking slots',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: userParkingSlots.length,
                    itemBuilder: (context, index) {
                      final slot = userParkingSlots[index];
                      bool isSelected = selectedSlotIds.contains(slot.id);
                      bool isAlreadyAssigned =
                          alreadyAssignedSlots.contains(slot.id);

                      return FutureBuilder<bool>(
                        future: _parkingScheduleService.isSlotAvailable(
                          countryId: request.countryId,
                          cityId: request.cityId,
                          locationId: widget.locationId,
                          userId: currentUserId,
                          slotId: slot.id,
                          startDate: request.startDate,
                          endDate: request.endDate,
                          startTime: request.startTime,
                          endTime: request.endTime,
                          checkAssignedRequests: true,
                        ),
                        builder: (context, snapshot) {
                          bool isAvailable = snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data == true;

                          return CheckboxListTile(
                            title: Text(slot.name),
                            subtitle: isAlreadyAssigned
                                ? Text(
                                    Provider.of<LocalizationService>(context,
                                                listen: false)
                                            .translate('alreadyAssigned') ??
                                        'Already assigned to this request.',
                                    style:
                                        const TextStyle(color: Colors.orange),
                                  )
                                : (isAvailable
                                    ? Text(
                                        Provider.of<LocalizationService>(
                                                    context,
                                                    listen: false)
                                                .translate('available') ??
                                            'Available',
                                      )
                                    : FutureBuilder<ParkingRequest?>(
                                        future: _parkingService
                                            .getAssignmentDetails(
                                          countryId: widget.countryId,
                                          cityId: widget.cityId,
                                          locationId: widget.locationId,
                                          slotId: slot.id,
                                          desiredStartDateTime: DateTime(
                                            request.startDate.year,
                                            request.startDate.month,
                                            request.startDate.day,
                                            int.parse(request.startTime
                                                .split(':')[0]),
                                            int.parse(request.startTime
                                                .split(':')[1]),
                                          ),
                                          desiredEndDateTime: DateTime(
                                            request.endDate.year,
                                            request.endDate.month,
                                            request.endDate.day,
                                            int.parse(
                                                request.endTime.split(':')[0]),
                                            int.parse(
                                                request.endTime.split(':')[1]),
                                          ),
                                        ),
                                        builder: (context, assignmentSnap) {
                                          if (assignmentSnap.connectionState ==
                                              ConnectionState.waiting) {
                                            return Text(
                                              Provider.of<LocalizationService>(
                                                          context,
                                                          listen: false)
                                                      .translate(
                                                          'occupiedCheckingDetails') ??
                                                  'Occupied (checking details...)',
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            );
                                          }
                                          if (assignmentSnap.hasError) {
                                            return Text(
                                              Provider.of<LocalizationService>(
                                                          context,
                                                          listen: false)
                                                      .translate('occupied') ??
                                                  'Occupied',
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            );
                                          }
                                          if (assignmentSnap.data == null) {
                                            return Text(
                                              Provider.of<LocalizationService>(
                                                          context,
                                                          listen: false)
                                                      .translate('occupied') ??
                                                  'Occupied',
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            );
                                          }

                                          final assignedRequest =
                                              assignmentSnap.data!;
                                          String dayOfWeek = _getDayOfWeek(
                                              assignedRequest.endDate.weekday);
                                          return Text(
                                            Provider.of<LocalizationService>(
                                                        context,
                                                        listen: false)
                                                    .translate(
                                                        'occupiedAssignedMessage')
                                                    .replaceAll(
                                                        '{requesterName}',
                                                        assignedRequest
                                                            .requesterId)
                                                    .replaceAll('{dayOfWeek}',
                                                        dayOfWeek)
                                                    .replaceAll(
                                                        '{startTime}',
                                                        assignedRequest
                                                            .startTime)
                                                    .replaceAll(
                                                        '{endTime}',
                                                        assignedRequest
                                                            .endTime) ??
                                                'Occupied because it has already been assigned to user ${assignedRequest.requesterId} on $dayOfWeek from ${assignedRequest.startTime}h to ${assignedRequest.endTime}h',
                                            style: const TextStyle(
                                                color: Colors.red),
                                          );
                                        },
                                      )),
                            value: isSelected,
                            onChanged: (bool? checked) async {
                              if (isAlreadyAssigned) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      Provider.of<LocalizationService>(context,
                                                  listen: false)
                                              .translate('alreadyAssigned') ??
                                          'This slot is already assigned to this request.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (!isAvailable) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      Provider.of<LocalizationService>(context,
                                                  listen: false)
                                              .translate('occupied') ??
                                          'This slot is already occupied during the requested time.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                if (checked == true) {
                                  selectedSlotIds.add(slot.id);
                                } else {
                                  selectedSlotIds.remove(slot.id);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      Provider.of<LocalizationService>(context, listen: false)
                              .translate('cancel') ??
                          'Cancel',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedSlotIds.isEmpty
                        ? null
                        : () async {
                            try {
                              await _parkingScheduleService.assignMultipleSlots(
                                countryId: request.countryId,
                                cityId: request.cityId,
                                locationId: widget.locationId,
                                requestId: request.requestId,
                                selectedSlotIds: selectedSlotIds,
                                assignedBy: currentUserId,
                              );

                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Provider.of<LocalizationService>(context,
                                                listen: false)
                                            .translate('approvalUpdated') ??
                                        'Approval updated.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    Provider.of<LocalizationService>(context,
                                                listen: false)
                                            .translate('approvalError') ??
                                        'Error approving request: $e',
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(
                      Provider.of<LocalizationService>(context, listen: false)
                              .translate('approve') ??
                          'Approve',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('approvalError') ??
                'Error: $e',
          ),
        ),
      );
    }
  }

  /// Delete a parking request
  Future<void> _deleteRequest(ParkingRequest request) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => const ConfirmDeletionDialog(),
    );

    if (confirm) {
      try {
        await _parkingScheduleService.deleteParkingRequest(
          countryId: request.countryId,
          cityId: request.cityId,
          locationId: request.locationId,
          requestId: request.requestId,
        );
        _showSnackBar(context, 'requestDeleted');
      } catch (e) {
        _showSnackBar(context, 'deleteError', isError: true);
      }
    }
  }

  /// Helper method to show snack bars with various messages
  void _showSnackBar(BuildContext context, String key, {bool isError = false}) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String message;
    switch (key) {
      case 'noParkingSlotsAvailable':
        message = localizationService.translate('noParkingSlotsAvailable') ??
            'No parking slots available for assignment.';
        break;
      case 'requestApprovedMessage':
        message = localizationService.translate('requestApprovedMessage') ??
            'Your request has been approved.';
        break;
      case 'requestApprovedPoints':
        message = localizationService.translate('requestApprovedPoints') ??
            'Request approved, +10 points!';
        break;
      case 'requestDeleted':
        message = localizationService.translate('requestDeleted') ??
            'Request deleted successfully.';
        break;
      case 'deleteError':
        message = localizationService.translate('deleteError') ??
            'Error deleting request.';
        break;
      case 'joinCommunityFirst':
        message = localizationService.translate('joinCommunityFirst') ??
            'Please join the community first.';
        break;
      default:
        message = key;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Getters for the Drawer header
  String get displayName => _currentUserData?['displayName'] ?? widget.username;
  String get profileImageUrl => _currentUserData?['profileImageUrl'] ?? '';
  int get userPoints => _currentUserData?['parkingPoints'] ?? 0;

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('parkingCommunity') ??
              'Parking Community',
        ),
      ),
      drawer: _buildDrawer(localizationService),
      body: !_isJoined
          ? _buildEmptyState(localizationService)
          : StreamBuilder<List<ParkingRequest>>(
              stream: _parkingScheduleService.getParkingRequests(
                countryId: widget.countryId,
                cityId: widget.cityId,
                locationId: widget.locationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      Provider.of<LocalizationService>(context, listen: false)
                              .translate('fetchRequestsError') ??
                          'Error fetching requests.',
                    ),
                  );
                }

                List<ParkingRequest> allRequests = snapshot.data?.where((req) {
                      DateTime requestEndDateTime = DateTime(
                        req.endDate.year,
                        req.endDate.month,
                        req.endDate.day,
                        int.parse(req.endTime.split(':')[0]),
                        int.parse(req.endTime.split(':')[1]),
                      );
                      return requestEndDateTime.isAfter(DateTime.now());
                    }).toList() ??
                    [];

                final userPendingRequests = allRequests
                    .where((req) =>
                        req.requesterId == currentUserId &&
                        req.status == 'pending' &&
                        !req.isExpired)
                    .toList();

                final incomingPendingRequests = allRequests
                    .where((req) =>
                        req.requesterId != currentUserId &&
                        req.status == 'pending' &&
                        !req.isExpired)
                    .toList();

                final assignedToYouRequests = allRequests
                    .where((req) =>
                        req.requesterId == currentUserId &&
                        (req.status == 'approved' ||
                            req.status == 'completed') &&
                        !req.isExpired)
                    .toList();

                final assignedByYouRequests = allRequests
                    .where((req) =>
                        req.requesterId != currentUserId &&
                        (req.status == 'approved' ||
                            req.status == 'completed') &&
                        req.assignedSlots.any((slotId) => _userParkingSlots
                            .any((userSlot) => userSlot.id == slotId)) &&
                        !req.isExpired)
                    .toList();

                bool noActiveRequests = userPendingRequests.isEmpty &&
                    incomingPendingRequests.isEmpty &&
                    assignedToYouRequests.isEmpty &&
                    assignedByYouRequests.isEmpty;

                if (noActiveRequests) {
                  return _buildEmptyState(localizationService);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (userPendingRequests.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              localizationService
                                      .translate('requestsSeeking') ??
                                  'Your open requests:',
                            ),
                            ...userPendingRequests.map(
                              (req) => _buildPendingRequestTile(
                                req,
                                localizationService,
                              ),
                            ),
                          ],
                        ),
                      if (incomingPendingRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          localizationService.translate('incomingRequests') ??
                              'Other open requests:',
                        ),
                        ...incomingPendingRequests.map(
                          (req) => _buildPendingRequestTile(
                            req,
                            localizationService,
                          ),
                        ),
                      ],
                      if (assignedToYouRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          localizationService.translate('assignedToYou') ??
                              'Assigned to you:',
                        ),
                        ..._buildApprovedRequests(
                          assignedToYouRequests,
                          localizationService,
                          isRequestedByUser: true,
                        ),
                      ],
                      if (assignedByYouRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          localizationService.translate('youAssigned') ??
                              'You assigned:',
                        ),
                        ..._buildApprovedRequests(
                          assignedByYouRequests,
                          localizationService,
                          isRequestedByUser: false,
                        ),
                      ],
                      if (!_isJoined)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: _buildJoinCommunityButton(localizationService),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDrawer(LocalizationService localizationService) {
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildDrawerHeader(localizationService),
              _buildDrawerListTile(
                icon: Icons.home,
                title: localizationService.translate('home') ?? 'Home',
                onTap: () => _navigateTo(
                  UserLocationsScreen(username: widget.username),
                ),
              ),
              const Divider(),
              _buildConditionalDrawerListTile(
                icon: Icons.schedule,
                title: localizationService.translate('defineAvailability') ??
                    'Define availability',
                onTap: () => _navigateToIfJoined(
                  DefineAvailabilityScreen(
                    userParkingSlots: _userParkingSlots,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                ),
                requiresJoin: true,
              ),
              ListTile(
                leading: const Icon(Icons.car_rental, color: Colors.blueAccent),
                title: Text(
                  localizationService.translate('requestParking') ??
                      'Request parking slot',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _navigateToIfJoined(
                  RequestParkingScreen(
                    userParkingSlots: _userParkingSlots,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                ),
              ),
              _buildDrawerListTile(
                icon: Icons.calendar_view_month,
                title: localizationService.translate('viewSchedule') ??
                    'View schedule',
                onTap: () => _navigateTo(
                  MonthsDaysScreen(
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                    username: widget.username,
                    locationAdmin: widget.locationAdmin,
                  ),
                ),
              ),
              if (_isJoined) ...[
                const Divider(),
                _buildDrawerListTile(
                  icon: Icons.edit,
                  title: localizationService.translate('editParkingSlots') ??
                      'Edit your parking slots',
                  onTap: () => _navigateTo(
                    EditParkingSlotsScreen(
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                      locationId: widget.locationId,
                    ),
                  ),
                ),
              ],
              if (widget.locationAdmin) ...[
                const Divider(),
                _buildDrawerListTile(
                  icon: Icons.manage_accounts,
                  title: localizationService.translate('manageRequests') ??
                      'Manage requests',
                  onTap: () => _navigateTo(
                    ManageRequestsScreen(
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                      locationId: widget.locationId,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(LocalizationService localizationService) {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: Colors.blueAccent),
      accountName: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      accountEmail: Text(
        '${localizationService.translate('points') ?? 'Points'}: $userPoints',
        style: const TextStyle(color: Colors.white70),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundImage: _getProfileImage(),
        radius: 20,
        child: _getProfileImage() == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              )
            : null,
      ),
    );
  }

  ImageProvider<Object>? _getProfileImage() {
    if (profileImageUrl.isNotEmpty && profileImageUrl.startsWith('http')) {
      return NetworkImage(profileImageUrl);
    } else if (profileImageUrl.isNotEmpty) {
      return AssetImage(profileImageUrl);
    }
    return const AssetImage('assets/images/default_user.png');
  }

  Widget _buildDrawerListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildConditionalDrawerListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool requiresJoin,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (requiresJoin) {
          if (_isJoined) {
            onTap();
          } else {
            _showSnackBar(context, 'joinCommunityFirst');
          }
        } else {
          onTap();
        }
      },
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _navigateToIfJoined(Widget screen) {
    if (_isJoined) {
      _navigateTo(screen);
    } else {
      _showSnackBar(context, 'joinCommunityFirst');
    }
  }

  Widget _buildEmptyState(LocalizationService localizationService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 120,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            localizationService.translate('noActiveRequests') ??
                'No active requests at the moment',
            style: const TextStyle(fontSize: 20, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (_isJoined) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestParkingScreen(
                      userParkingSlots: _userParkingSlots,
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                      locationId: widget.locationId,
                    ),
                  ),
                );
              } else {
                _showJoinParkingDialog();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              _isJoined
                  ? (localizationService.translate('createRequest') ??
                      'Create request')
                  : (localizationService.translate('joinCommunity') ??
                      'Join parking community'),
              style: const TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCommunityButton(LocalizationService localizationService) {
    return Center(
      child: ElevatedButton(
        onPressed: _showJoinParkingDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          localizationService.translate('joinCommunity') ??
              'Join parking community',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Widget> _buildApprovedRequests(
    List<ParkingRequest> approvedRequests,
    LocalizationService localizationService, {
    required bool isRequestedByUser,
  }) {
    return approvedRequests.map((req) {
      return ApprovedRequestTile(
        request: req,
        services: _parkingScheduleService,
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
        localizationService: localizationService,
        isRequester: isRequestedByUser,
      );
    }).toList();
  }

  Widget _buildPendingRequestTile(
    ParkingRequest req,
    LocalizationService localizationService,
  ) {
    bool isRequester = req.requesterId == currentUserId;
    bool isExpired = req.isExpired;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userService.getUserDocumentById(req.requesterId),
      builder: (context, userSnap) {
        String requesterName = req.requesterId;
        String requesterImage = '';
        if (userSnap.connectionState == ConnectionState.done &&
            userSnap.hasData &&
            userSnap.data != null) {
          requesterName = userSnap.data!['displayName'] ?? req.requesterId;
          requesterImage = userSnap.data!['profileImageUrl'] ?? '';
        }

        String timeString = _formatRequestTime(
          req.startDate,
          req.startTime,
          req.endDate,
          req.endTime,
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isExpired ? Colors.grey.shade300 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (!isExpired)
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
            ],
            border: req.assignedSlots.isNotEmpty && req.numberOfSpots > 0
                ? Border.all(color: Colors.orange, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _getRequesterImage(requesterImage),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          requesterName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isExpired)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              localizationService.translate('expired') ??
                                  'Expired',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isRequester && req.numberOfSpots > 0 && !isExpired)
                    ElevatedButton(
                      onPressed: () async => await _approveRequest(req),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        localizationService.translate('approve') ?? 'Approve',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  if (isRequester)
                    TextButton(
                      onPressed: () => _deleteRequest(req),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        localizationService.translate('delete') ?? 'Delete',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${localizationService.translate('requestedSpots') ?? 'Requested spots'}: ${req.numberOfSpots}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${localizationService.translate('assignedSpots') ?? 'Assigned spots'}: ${req.assignedSlots.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                timeString,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (req.message.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.message,
                        color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req.message,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  ImageProvider<Object> _getRequesterImage(String requesterImage) {
    if (requesterImage.isNotEmpty && requesterImage.startsWith('http')) {
      return NetworkImage(requesterImage);
    } else if (requesterImage.isNotEmpty) {
      return AssetImage(requesterImage);
    }
    return const AssetImage('assets/images/default_user.png');
  }

  String _formatRequestTime(
    DateTime startDate,
    String startTime,
    DateTime endDate,
    String endTime,
  ) {
    final startDateStr =
        '${_twoDigits(startDate.day)}.${_twoDigits(startDate.month)}';
    final endDateStr =
        '${_twoDigits(endDate.day)}.${_twoDigits(endDate.month)}';

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return '$startDateStr (${startTime}h - ${endTime}h)';
    } else {
      return '$startDateStr (${startTime}h) - $endDateStr (${endTime}h)';
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _getDayOfWeek(int weekday) {
    // Optionally, you might retrieve localized day names via your localization service.
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}

class ConfirmDeletionDialog extends StatelessWidget {
  const ConfirmDeletionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return AlertDialog(
      title: Text(
        localizationService.translate('confirmDeletion') ?? 'Confirm deletion',
      ),
      content: Text(
        localizationService.translate('confirmDeletionContent') ??
            'Are you sure you want to delete this request?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            localizationService.translate('cancel') ?? 'Cancel',
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            localizationService.translate('delete') ?? 'Delete',
          ),
        ),
      ],
    );
  }
}

class ApprovedRequestTile extends StatelessWidget {
  final ParkingRequest request;
  final ParkingScheduleService services;
  final String countryId;
  final String cityId;
  final String locationId;
  final LocalizationService localizationService;
  final bool isRequester;

  const ApprovedRequestTile({
    super.key,
    required this.request,
    required this.services,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.localizationService,
    required this.isRequester,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: services.getAssignedSpots(
        countryId: countryId,
        cityId: cityId,
        locationId: locationId,
        requestId: request.requestId,
      ),
      builder: (context, spotSnap) {
        if (spotSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (spotSnap.hasError) {
          return Text(
            '${localizationService.translate('assignedSpotsError') ?? 'Error fetching assigned spots'}: ${spotSnap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        if (spotSnap.hasData && spotSnap.data!.isNotEmpty) {
          List<String> assignedSpotIds = spotSnap.data!.toSet().toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: assignedSpotIds.map((slotId) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: services.getSlotOwnerData(
                  countryId: countryId,
                  cityId: cityId,
                  locationId: locationId,
                  slotId: slotId,
                ),
                builder: (context, ownerSnap) {
                  if (ownerSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (ownerSnap.hasError) {
                    return Text(
                      '${localizationService.translate('slotOwnerError') ?? 'Error fetching slot owner'}: ${ownerSnap.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  if (!ownerSnap.hasData || ownerSnap.data == null) {
                    return Text(
                      localizationService.translate('unknownSlotOwner') ??
                          'Unknown parking slot owner.',
                    );
                  }

                  Map<String, dynamic>? ownerData = ownerSnap.data;
                  String ownerName = ownerData?['displayName'] ??
                      (localizationService.translate('unknown') ?? 'Unknown');
                  String ownerImage = ownerData?['profileImageUrl'] ?? '';

                  return FutureBuilder<String>(
                    future: services.getSlotName(
                      countryId: countryId,
                      cityId: cityId,
                      locationId: locationId,
                      slotId: slotId,
                    ),
                    builder: (context, nameSnap) {
                      if (nameSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (nameSnap.hasError) {
                        return Text(
                          '${localizationService.translate('slotNameError') ?? 'Error fetching slot name'}: ${nameSnap.error}',
                          style: const TextStyle(color: Colors.red),
                        );
                      }

                      String slotName = nameSnap.data ??
                          (localizationService.translate('unknown') ??
                              'Unknown');
                      String timeString = _formatRequestTime(
                        request.startDate,
                        request.startTime,
                        request.endDate,
                        request.endTime,
                      );

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRequester
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                          border: Border.all(
                            color: isRequester
                                ? Colors.blue.shade300
                                : Colors.green.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: _getOwnerImage(ownerImage),
                              radius: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRequester
                                        ? (localizationService
                                                .translate('assignedToYou') ??
                                            'Assigned to you:')
                                        : (localizationService
                                                .translate('youAssigned') ??
                                            'You assigned:'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$ownerName ($slotName)',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    timeString,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        } else {
          return Text(
            localizationService.translate('noAssignedSpots') ??
                'No assigned spots for this approved request.',
            style: const TextStyle(fontSize: 16),
          );
        }
      },
    );
  }

  ImageProvider<Object> _getOwnerImage(String ownerImage) {
    if (ownerImage.isNotEmpty && ownerImage.startsWith('http')) {
      return NetworkImage(ownerImage);
    } else if (ownerImage.isNotEmpty) {
      return AssetImage(ownerImage);
    }
    return const AssetImage('assets/images/default_user.png');
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatRequestTime(
    DateTime startDate,
    String startTime,
    DateTime endDate,
    String endTime,
  ) {
    final startDateStr =
        '${_twoDigits(startDate.day)}.${_twoDigits(startDate.month)}';
    final endDateStr =
        '${_twoDigits(endDate.day)}.${_twoDigits(endDate.month)}';

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return '$startDateStr (${startTime}h - ${endTime}h)';
    } else {
      return '$startDateStr (${startTime}h) - $endDateStr (${endTime}h)';
    }
  }
}
