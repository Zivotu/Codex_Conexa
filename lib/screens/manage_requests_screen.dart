import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/parking_schedule_service.dart';
import '../services/user_service.dart';
import '../models/parking_request.dart';
import '../models/parking_slot.dart';
import '../services/localization_service.dart';

class ManageRequestsScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const ManageRequestsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _ManageRequestsScreenState createState() => _ManageRequestsScreenState();
}

class _ManageRequestsScreenState extends State<ManageRequestsScreen> {
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();
  final UserService _userService = UserService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh widget every 60 seconds to re-evaluate the current date/time.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _approveRequest(ParkingRequest request) async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localization.translate('userNotLoggedIn') ??
                'User is not logged in.')),
      );
      return;
    }
    String currentUserId = currentUser.uid;
    List<ParkingSlot> availableSlots =
        await _parkingScheduleService.getAvailableUserParkingSlots(
      countryId: request.countryId,
      cityId: request.cityId,
      locationId: request.locationId,
      startDate: request.startDate,
      endDate: request.endDate,
      requestStartTime: request.startTime,
      requestEndTime: request.endTime,
      userId: currentUserId,
    );
    if (availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localization.translate('noAvailableParkingSlots') ??
              'No available parking slots for assignment.'),
        ),
      );
      return;
    }
    List<String> selectedSlotIds = [];
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(localization.translate('assignParkingSlot') ??
                  'Assign parking slot'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableSlots.length,
                  itemBuilder: (context, index) {
                    final slot = availableSlots[index];
                    bool isSelected = selectedSlotIds.contains(slot.id);
                    return CheckboxListTile(
                      title: Text(slot.name),
                      value: isSelected,
                      onChanged: (bool? checked) {
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localization.translate('cancel') ?? 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedSlotIds.isEmpty
                      ? null
                      : () async {
                          try {
                            await _parkingScheduleService.assignMultipleSlots(
                              countryId: request.countryId,
                              cityId: request.cityId,
                              locationId: request.locationId,
                              requestId: request.requestId,
                              selectedSlotIds: selectedSlotIds,
                              assignedBy: currentUserId,
                            );
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    localization.translate('approvalUpdated') ??
                                        'Approval updated.'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${localization.translate('approvalError') ?? 'Error approving request: '}$e',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    localization.translate('approve') ?? 'Approve',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _declineRequest(ParkingRequest request) async {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    await _parkingScheduleService.updateParkingRequestStatus(
      countryId: request.countryId,
      cityId: request.cityId,
      locationId: request.locationId,
      requestId: request.requestId,
      newStatus: 'declined',
      message: localization.translate('requestDeclinedMessage') ??
          'Your request has been declined.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(localization.translate('requestDeclined') ??
              'Request declined.')),
    );
  }

  String _formatDateTime(DateTime date, String time) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} $time';
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(localization.translate('manageRequests') ?? 'Manage Requests'),
      ),
      body: StreamBuilder<List<ParkingRequest>>(
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
                localization
                        .translate('errorFetchingRequests')
                        .replaceAll('{error}', snapshot.error.toString()) ??
                    'Error: ${snapshot.error}',
              ),
            );
          }
          // Filter requests based on expiration
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

          List<ParkingRequest> pendingRequests =
              allRequests.where((req) => req.status == 'pending').toList();

          if (pendingRequests.isEmpty) {
            return Center(
              child: Text(localization.translate('noPendingRequests') ??
                  'No pending requests.'),
            );
          }

          return ListView.builder(
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final request = pendingRequests[index];
              return FutureBuilder<Map<String, dynamic>?>(
                future: _userService.getUserDocumentById(request.requesterId),
                builder: (context, userSnap) {
                  String requesterName = request.requesterId;
                  String requesterImage = '';
                  if (userSnap.connectionState == ConnectionState.done &&
                      userSnap.hasData &&
                      userSnap.data != null) {
                    requesterName =
                        userSnap.data!['displayName'] ?? request.requesterId;
                    requesterImage = userSnap.data!['profileImageUrl'] ?? '';
                  }
                  String timeString =
                      '${_formatDateTime(request.startDate, request.startTime)} - ${_formatDateTime(request.endDate, request.endTime)}';
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: (request.status == 'approved' ||
                              request.status == 'completed')
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (localization.translate('requestForSpots') ??
                                        'Request for {spots} slot(s)')
                                    .replaceAll('{spots}',
                                        request.numberOfSpots.toString()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeString,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (request.message.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.message,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        request.message,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _approveRequest(request),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      localization.translate('approve') ??
                                          'Approve',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _declineRequest(request),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      localization.translate('decline') ??
                                          'Decline',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: CircleAvatar(
                            backgroundImage: (requesterImage.isNotEmpty &&
                                    requesterImage.startsWith('http'))
                                ? NetworkImage(requesterImage)
                                : const AssetImage(
                                        'assets/images/default_user.png')
                                    as ImageProvider,
                            radius: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
