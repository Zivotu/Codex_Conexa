import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'commute_chat_screen.dart';
import '../models/ride_model.dart';
import '../viewmodels/ride_view_model.dart';
import '../services/user_service.dart';
import 'active_ride_map_screen.dart';
import '../commute_widgets/commute_map_picker.dart';
import '../services/commute_service.dart';
import 'commute_rides_list_screen.dart';
import '../services/localization_service.dart';

class BlinkingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const BlinkingIcon({super.key, required this.icon, required this.color});

  @override
  _BlinkingIconState createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<BlinkingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Icon(widget.icon, color: widget.color, size: 16),
    );
  }
}

class CommuteRideDetailScreen extends StatefulWidget {
  final String rideId;
  final String userId;

  const CommuteRideDetailScreen({
    super.key,
    required this.rideId,
    required this.userId,
  });

  @override
  _CommuteRideDetailScreenState createState() =>
      _CommuteRideDetailScreenState();
}

class _CommuteRideDetailScreenState extends State<CommuteRideDetailScreen> {
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};
  Set<Marker> _exitMarkers = {};
  Set<Polyline> _polylines = {};

  final List<LatLng> _directionPoints = [];
  LatLngBounds? _initialBounds;

  bool _hasRated = false;
  bool _isFullScreen = false;
  bool _hasFinishedForThisPassenger = false;

  Ride? _cachedRide;
  List<LatLng> _cachedDirectionPoints = [];

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rideshare')
          .doc(widget.rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.green,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                localizationService.translate('ride_details') ??
                    'Detalji vožnje',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            body: Center(
              child: Text(
                localizationService.translate('error_or_no_ride') ??
                    'Greška ili vožnja ne postoji.',
              ),
            ),
          );
        }

        final docData = snapshot.data!;
        final ride = Ride.fromFirestore(docData);

        final isDriver = ride.driverId == widget.userId;
        final isPassenger = ride.passengers.contains(widget.userId);
        final passengerStatus = ride.passengersStatus?[widget.userId];
        _hasFinishedForThisPassenger =
            passengerStatus != null && passengerStatus['hasFinished'] == true;

        final bool isNewRide =
            (_cachedRide == null || ride.rideId != _cachedRide!.rideId);

        if (isNewRide) {
          _cachedRide = ride;
          _setupMapData(ride);
        }

        final driverPhotoUrl = ride.driverPhotoUrl;
        final driverImage = (driverPhotoUrl.isNotEmpty)
            ? (driverPhotoUrl.startsWith('http')
                ? NetworkImage(driverPhotoUrl)
                : AssetImage(driverPhotoUrl) as ImageProvider)
            : null;

        String localStatus = _statusToString(ride.status, localizationService);
        if (!isDriver && _hasFinishedForThisPassenger) {
          localStatus = localizationService.translate('exited') ?? "Izašao";
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.green,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              localizationService.translate('ride_details') ?? 'Detalji vožnje',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                onPressed: () {
                  setState(() {
                    _isFullScreen = !_isFullScreen;
                  });
                },
              ),
            ],
          ),
          body: _isFullScreen
              ? _buildFullScreenMap(ride)
              : _buildNormalLayout(
                  ride,
                  rideViewModel,
                  userService,
                  driverImage,
                  isDriver,
                  isPassenger,
                  localStatus,
                  localizationService,
                ),
        );
      },
    );
  }

  Widget _buildNormalLayout(
    Ride ride,
    RideViewModel rideViewModel,
    UserService userService,
    ImageProvider? driverImage,
    bool isDriver,
    bool isPassenger,
    String localStatus,
    LocalizationService localizationService,
  ) {
    return Container(
      decoration: ride.status == RideStatus.active
          ? BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFullScreen = true;
                    });
                  },
                  child: GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_initialBounds != null) {
                        _mapController?.moveCamera(
                          CameraUpdate.newLatLngBounds(_initialBounds!, 60),
                        );
                      }
                    },
                    markers: _markers.union(_exitMarkers),
                    polylines: _polylines,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(45.8150, 15.9819),
                      zoom: 6,
                    ),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                FutureBuilder<List<Map<String, dynamic>?>>(
                  future: Future.wait(ride.passengers.map((passengerId) {
                    return userService.getUserDocumentById(passengerId);
                  })),
                  builder: (context, snapshotUsers) {
                    final passengerDocs = snapshotUsers.data ?? [];
                    return Row(
                      children: [
                        Icon(Icons.drive_eta, color: Colors.green),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: driverImage,
                          child: (driverImage == null)
                              ? const Icon(Icons.person,
                                  size: 30, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ride.driverName,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const Spacer(),
                        if (passengerDocs.isNotEmpty) ...[
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 6),
                          Row(
                            children: passengerDocs.map((doc) {
                              if (doc == null) {
                                return const Padding(
                                  padding: EdgeInsets.only(right: 4.0),
                                  child: CircleAvatar(
                                    radius: 16,
                                    child: Icon(Icons.person,
                                        size: 18, color: Colors.grey),
                                  ),
                                );
                              }
                              final piUrl =
                                  doc['profileImageUrl'] as String? ?? '';
                              final hasExited =
                                  ride.passengersStatus?[doc['uid']] != null &&
                                      ride.passengersStatus?[doc['uid']]
                                              ['hasFinished'] ==
                                          true;

                              final userProfileImage =
                                  (piUrl.isNotEmpty && piUrl.startsWith('http'))
                                      ? NetworkImage(piUrl)
                                      : (piUrl.isNotEmpty
                                          ? AssetImage(piUrl)
                                          : null) as ImageProvider?;
                              return Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: userProfileImage,
                                      child: (userProfileImage == null)
                                          ? const Icon(Icons.person,
                                              size: 18, color: Colors.grey)
                                          : null,
                                    ),
                                    if (hasExited)
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(2.0),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.flag, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      localizationService.translate('start_point') ??
                          'Polazište:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Text(ride.startAddress),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      localizationService.translate('destination') ??
                          'Odredište:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                Text(ride.endAddress),
                const SizedBox(height: 8),
                if (isPassenger) ...[
                  Text(
                    localizationService.translate('you_are_passenger') ??
                        'Vi ste putnik u ovoj vožnji',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
                if (isDriver) ...[
                  Text(
                    localizationService.translate('your_ride_driver') ??
                        'Ovo je Vaša vožnja (Vi ste vozač).',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd.MM.yyyy. HH:mm')
                          .format(ride.departureTime),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (ride.status == RideStatus.requested)
                      const Icon(Icons.hourglass_empty, color: Colors.grey)
                    else
                      const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${localizationService.translate('status') ?? 'Status'}: $localStatus',
                      style: TextStyle(
                        fontSize: 16,
                        color: _statusColor(ride.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (ride.status == RideStatus.active &&
                        !_hasFinishedForThisPassenger) ...[
                      const SizedBox(width: 6),
                      const BlinkingIcon(
                        icon: Icons.circle,
                        color: Colors.green,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildDynamicButtons(ride, localizationService),
                const Divider(thickness: 1),
                const SizedBox(height: 8),
                _buildCandiesDonationsList(ride, localizationService),
                const Divider(thickness: 1),
                if (!(ride.status == RideStatus.canceled)) ...[
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        localizationService
                                .translate('chat_with_driver_passengers') ??
                            'Chat s vozačem i putnicima',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CommuteChatScreen(
                      rideId: ride.rideId,
                      userId: widget.userId,
                      isReadOnly: (ride.status == RideStatus.completed ||
                          ride.status == RideStatus.canceled),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenMap(Ride ride) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            if (_initialBounds != null) {
              _mapController?.moveCamera(
                CameraUpdate.newLatLngBounds(_initialBounds!, 60),
              );
            }
          },
          markers: _markers.union(_exitMarkers),
          polylines: _polylines,
          initialCameraPosition: const CameraPosition(
            target: LatLng(45.8150, 15.9819),
            zoom: 6,
          ),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ],
    );
  }

  Color _statusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return Colors.purple;
      case RideStatus.active:
        return Colors.green;
      case RideStatus.completed:
        return Colors.blue;
      case RideStatus.canceled:
        return Colors.red;
      case RideStatus.open:
      default:
        return Colors.orange;
    }
  }

  String _statusToString(
      RideStatus status, LocalizationService localizationService) {
    switch (status) {
      case RideStatus.requested:
        return localizationService.translate('ride_requested') ??
            'Zatražena vožnja';
      case RideStatus.active:
        return localizationService.translate('ride_active') ?? 'U vožnji';
      case RideStatus.completed:
        return localizationService.translate('ride_completed') ?? 'Završena';
      case RideStatus.canceled:
        return localizationService.translate('ride_canceled') ?? 'Otkazana';
      case RideStatus.open:
      default:
        return localizationService.translate('ride_open') ?? 'Otvorena';
    }
  }

  Widget _buildDynamicButtons(
      Ride ride, LocalizationService localizationService) {
    final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
    final isDriver = ride.driverId == widget.userId;
    final passengerStatus = ride.passengersStatus?[widget.userId];
    final hasFinished =
        passengerStatus != null && passengerStatus['hasFinished'] == true;
    final isAccepted = ride.passengers.contains(widget.userId);
    final hasRequested =
        ride.passengerRequests.any((req) => req['userId'] == widget.userId);

    List<Widget> buttons = [];

    // START / FINISH / TRACK ride (driver)
    if (ride.status != RideStatus.completed &&
        ride.status != RideStatus.canceled &&
        ride.status != RideStatus.active &&
        isDriver) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await rideViewModel.startRide(ride.rideId);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ActiveRideMapScreen(rideId: ride.rideId),
                ),
              );
            }
          },
          icon: const Icon(Icons.directions_car),
          label: Text(
            localizationService.translate('start_ride') ?? 'Započni vožnju',
          ),
        ),
      );
    }

    if (isDriver && ride.status == RideStatus.active) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await rideViewModel.finishRide(ride.rideId);
            if (mounted) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(
            localizationService.translate('finish_ride') ?? 'Završi vožnju',
          ),
        ),
      );
    }

    if (ride.status == RideStatus.active) {
      if (!hasFinished) {
        buttons.add(
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ActiveRideMapScreen(rideId: ride.rideId),
                ),
              );
            },
            icon: const Icon(Icons.navigation),
            label: Text(
              localizationService.translate('track_ride') ?? 'Praćenje vožnje',
            ),
          ),
        );
      }
    }

    // FINISH ride for passenger
    if (!isDriver && ride.status == RideStatus.active && !hasFinished) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  localizationService.translate('finish_ride') ??
                      'Završiti vožnju',
                ),
                content: Text(
                  localizationService.translate('confirm_exit_ride') ??
                      'Jeste li sigurni da želite izaći iz vožnje?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(localizationService.translate('no') ?? 'Ne'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(localizationService.translate('yes') ?? 'Da'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              final position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high);
              final finalLoc = GeoPoint(position.latitude, position.longitude);

              await rideViewModel.finishRideForPassenger(
                ride.rideId,
                widget.userId,
                finalLocation: finalLoc,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizationService.translate('ride_finished_for_you') ??
                          'Vožnja završena za Vas.',
                    ),
                  ),
                );
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(
                      localizationService.translate('ride_completed') ??
                          'Vožnja završena',
                    ),
                    content: Text(
                      localizationService.translate('thank_you_exit') ??
                          'Uspješno ste izašli iz vožnje. Hvala Vam!',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommuteRidesListScreen(
                      username: 'Primjer korisnik',
                      countryId: 'HR',
                      cityId: 'Zagreb',
                      locationId: '12345',
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.check_circle_outline),
          label: Text(
            localizationService.translate('finish_ride_for_self') ??
                'Završi vožnju za sebe',
          ),
        ),
      );
    }

    // JOIN request button for passenger
    if (!isDriver &&
        ride.status == RideStatus.open &&
        !hasRequested &&
        !isAccepted) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final pickUpPoint = await _pickLocation(
              title: localizationService.translate('choose_pickup_point') ??
                  'Odaberi točku preuzimanja',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizationService.translate('choose_pickup_prompt') ??
                        'Odaberi točku preuzimanja',
                  ),
                ),
              );
            }
            final exitPoint = await _pickLocation(
              title: localizationService.translate('choose_exit_location') ??
                  'Odaberi izlaznu lokaciju',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizationService.translate('choose_exit_prompt') ??
                        'Odaberi izlaznu lokaciju',
                  ),
                ),
              );
            }

            await rideViewModel.joinRide(
              ride.rideId,
              widget.userId,
              exitLocation: exitPoint,
            );
            if (pickUpPoint != null) {
              await _updatePickUpLocation(
                ride.rideId,
                widget.userId,
                pickUpPoint,
              );
            }
          },
          icon: const Icon(Icons.send),
          label: Text(
            localizationService.translate('request_ride') ?? 'Zatraži vožnju',
          ),
        ),
      );
    }

    // CHANGE exit location
    if (!isDriver &&
        (hasRequested || isAccepted) &&
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.active &&
        ride.status != RideStatus.canceled) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final location = await _pickLocation(
              title: localizationService.translate('choose_exit_location') ??
                  'Odaberi izlaznu lokaciju',
            );
            if (location != null) {
              await rideViewModel.updatePassengerExitLocation(
                ride.rideId,
                widget.userId,
                location,
              );
            }
          },
          icon: const Icon(Icons.edit_location_alt),
          label: Text(
            localizationService.translate('change_exit_point') ??
                'Promijeni izlaznu točku',
          ),
        ),
      );
    }

    // CANCEL ride as passenger
    if (!isDriver &&
        isAccepted &&
        ride.status != RideStatus.active &&
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.canceled) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  localizationService.translate('cancel_participation') ??
                      'Otkaži sudjelovanje',
                ),
                content: Text(
                  localizationService.translate('confirm_cancel') ??
                      'Jeste li sigurni da želite otkazati?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(localizationService.translate('no') ?? 'Ne'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(localizationService.translate('yes') ?? 'Da'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await rideViewModel.cancelRideAsPassenger(
                ride.rideId,
                widget.userId,
              );
            }
          },
          icon: const Icon(Icons.close),
          label: Text(localizationService.translate('cancel') ?? 'Otkaži'),
        ),
      );
    }

    // RATE driver (when ride completed for passenger)
    if (!isDriver && ride.status == RideStatus.completed && !_hasRated) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _showRateUserDialog(ride, localizationService),
          icon: const Icon(Icons.star_rate_rounded),
          label: Text(
            localizationService.translate('rate_driver') ?? 'Ocijeni Vozača',
          ),
        ),
      );
    }

    // Passenger requests list (driver sees pending requests)
    if (isDriver &&
        (ride.status == RideStatus.requested ||
            ride.status == RideStatus.open) &&
        ride.passengerRequests.isNotEmpty) {
      buttons.add(_buildPassengerRequestsList(ride, localizationService));
    }

    // CANCEL ride as driver
    if (isDriver &&
        ride.status != RideStatus.active &&
        ride.status != RideStatus.completed &&
        ride.status != RideStatus.canceled) {
      buttons.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  localizationService.translate('cancel_ride') ??
                      'Otkaži vožnju',
                ),
                content: Text(
                  localizationService.translate('confirm_cancel_ride') ??
                      'Jeste li sigurni da želite otkazati?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(localizationService.translate('no') ?? 'Ne'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(localizationService.translate('yes') ?? 'Da'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await rideViewModel.cancelRideAsDriver(ride.rideId);
            }
          },
          icon: const Icon(Icons.cancel_schedule_send),
          label: Text(
            localizationService.translate('cancel_ride') ?? 'Otkaži vožnju',
          ),
        ),
      );
    }

    // GIFT candies
    final totalCandies = _getTotalCandies(ride);

    bool canGiftCandies = false;
    if (ride.status == RideStatus.active) {
      canGiftCandies = true;
    } else if (ride.status == RideStatus.completed) {
      final diff = DateTime.now().difference(ride.departureTime).inMinutes;
      if (diff < 30) {
        canGiftCandies = true;
      }
    }

    // Prikaži gumb samo ako je < 100 ukupno poklonjenih bonbona
    if (!isDriver && canGiftCandies && !hasFinished && totalCandies < 100) {
      buttons.add(const SizedBox(height: 16));
      buttons.add(_buildGiftButton(ride, localizationService));
    }

    // Prikaz koliko je ukupno bonbona poklonjeno - samo vozač vidi
    if (isDriver && totalCandies > 0) {
      buttons.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              const Icon(Icons.cake, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '${localizationService.translate('total_candies') ?? 'Ukupno poklonjenih bonbona'}: $totalCandies',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buttons,
    );
  }

  Widget _buildCandiesDonationsList(
      Ride ride, LocalizationService localizationService) {
    final donations = ride.passengerRequests
        .where((req) => (req['candiesDonated'] ?? 0) > 0)
        .toList();
    if (donations.isEmpty) {
      return const SizedBox.shrink();
    }
    final userService = Provider.of<UserService>(context, listen: false);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(donations.map((don) async {
        final userId = don['userId'];
        final doc = await userService.getUserDocumentById(userId);
        return {
          'userId': userId,
          'candies': don['candiesDonated'],
          'message': don['message'] ?? '',
          'displayName': doc?['displayName'] ?? 'Nepoznat',
          'profileImageUrl': doc?['profileImageUrl'] ?? '',
        };
      })),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final dataList = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizationService.translate('gifted_candies') ??
                  'Darovani bonboni:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...dataList.map((don) {
              final profileImageUrl = don['profileImageUrl'] as String;
              ImageProvider? userProfileImage;
              if (profileImageUrl.isNotEmpty) {
                if (profileImageUrl.startsWith('http')) {
                  userProfileImage = NetworkImage(profileImageUrl);
                } else {
                  userProfileImage = AssetImage(profileImageUrl);
                }
              }
              final name = don['displayName'];
              final candies = don['candies'];
              final msg = don['message'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: userProfileImage,
                      child: (userProfileImage == null)
                          ? const Icon(Icons.person,
                              size: 18, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_right, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '$candies',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.cake,
                              color: Colors.purple, size: 16),
                          if (msg.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_right, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msg,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildGiftButton(Ride ride, LocalizationService localizationService) {
    final rideViewModel = Provider.of<RideViewModel>(context, listen: false);

    double candyValue = 0;
    final TextEditingController msgController = TextEditingController();

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(builder: (ctx, setStateDialog) {
              return AlertDialog(
                title: Text(
                  localizationService.translate('gift_candies') ??
                      'Pokloni bonbone',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.card_giftcard, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            localizationService
                                    .translate('number_of_candies') ??
                                'Broj bonbona (0-100)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: candyValue,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: candyValue.toInt().toString(),
                        onChanged: (val) {
                          setStateDialog(() {
                            candyValue = val;
                          });
                        },
                      ),
                      Text(
                        '${localizationService.translate('selected') ?? 'Odabrano'}: ${candyValue.toInt()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: msgController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: localizationService
                                  .translate('message_optional') ??
                              'Poruka (nije obvezna)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      localizationService.translate('cancel') ?? 'Odustani',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final candies = candyValue.toInt();

                      // Lokalna provjera da ne pređemo 100 ukupno
                      final totalAlreadyDonated =
                          ride.passengerRequests.fold<int>(
                        0,
                        (sum, item) =>
                            sum + (item['candiesDonated'] as int? ?? 0),
                      );
                      if (totalAlreadyDonated + candies > 100) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizationService.translate(
                                        'cannot_gift_more_than_100') ??
                                    'Ne možete pokloniti više od 100 bonbona za ovu vožnju.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      if (candies >= 0 && candies <= 100) {
                        await rideViewModel.giftCandiesToDriver(
                          ride.rideId,
                          ride.driverId,
                          widget.userId,
                          candies,
                          msgController.text.trim().isEmpty
                              ? null
                              : msgController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizationService
                                        .translate('invalid_candies') ??
                                    'Neispravan broj bonbona!',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      localizationService.translate('gift') ?? 'Pokloni',
                    ),
                  ),
                ],
              );
            });
          },
        );
      },
      icon: const Icon(Icons.card_giftcard),
      label: Text(
        localizationService.translate('gift_candies_to_driver') ??
            'Pokloni bonbone vozaču',
      ),
    );
  }

  int _getTotalCandies(Ride ride) {
    return ride.passengerRequests.fold<int>(
      0,
      (sum, item) => sum + (item['candiesDonated'] as int? ?? 0),
    );
  }

  Future<GeoPoint?> _pickLocation({String title = 'Lokacija'}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommuteMapPicker(title: title),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      final latitude = result['latitude'] as double;
      final longitude = result['longitude'] as double;
      return GeoPoint(latitude, longitude);
    }
    return null;
  }

  Future<void> _updatePickUpLocation(
      String rideId, String passengerId, GeoPoint pickUpLocation) async {
    final docRef =
        FirebaseFirestore.instance.collection('rideshare').doc(rideId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final passengerRequests =
          List<Map<String, dynamic>>.from(data['passengerRequests'] ?? []);
      final idx =
          passengerRequests.indexWhere((r) => r['userId'] == passengerId);
      if (idx != -1) {
        passengerRequests[idx]['pickUpLocation'] = pickUpLocation;
      }
      transaction.update(docRef, {
        'passengerRequests': passengerRequests,
      });
    });
  }

  Widget _buildPassengerRequestsList(
      Ride ride, LocalizationService localizationService) {
    final userService = Provider.of<UserService>(context, listen: false);
    final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
    final pendingRequests = ride.passengerRequests
        .where((req) => req['isAccepted'] == false)
        .toList();
    if (pendingRequests.isEmpty) {
      return Text(
        localizationService.translate('no_new_requests') ??
            'Nema novih zahtjeva.',
      );
    }

    Future<String> getAddressFromGeoPoint(GeoPoint location) async {
      try {
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          return "${placemark.street}, ${placemark.locality}";
        }
        return localizationService.translate('unknown_location') ??
            "Nepoznata lokacija";
      } catch (e) {
        return localizationService.translate('unknown_location') ??
            "Nepoznata lokacija";
      }
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(
        pendingRequests.map((req) async {
          final userDoc = await userService.getUserDocumentById(req['userId']);
          final exitLocation = req['exitLocation'] as GeoPoint?;
          final pickUpLocation = req['pickUpLocation'] as GeoPoint?;

          String exitAddress =
              localizationService.translate('exit_point_not_set') ??
                  "Izlazna točka nije postavljena";
          String pickUpAddress =
              localizationService.translate('pickup_not_set') ??
                  "Točka ukrcaja nije postavljena";

          if (exitLocation != null) {
            exitAddress = await getAddressFromGeoPoint(exitLocation);
          }
          if (pickUpLocation != null) {
            pickUpAddress = await getAddressFromGeoPoint(pickUpLocation);
          }

          final displayName = userDoc?['displayName'] ?? 'Korisnik';
          final profileImageUrl = userDoc?['profileImageUrl'] ?? '';

          return {
            'userId': req['userId'],
            'exitAddress': exitAddress,
            'pickUpAddress': pickUpAddress,
            'isAccepted': req['isAccepted'],
            'displayName': displayName,
            'profileImageUrl': profileImageUrl,
          };
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }
        final passengersData = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizationService.translate('passenger_requests') ??
                  'Zahtjevi putnika:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...passengersData.map((p) {
              final profileImageUrl = p['profileImageUrl'] as String;
              ImageProvider? profileImage;
              if (profileImageUrl.isNotEmpty) {
                if (profileImageUrl.startsWith('http')) {
                  profileImage = NetworkImage(profileImageUrl);
                } else {
                  profileImage = AssetImage(profileImageUrl);
                }
              }
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Colors.grey,
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: profileImage,
                            radius: 25,
                            child: (profileImage == null)
                                ? const Icon(Icons.person,
                                    size: 30, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p['displayName'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            localizationService.translate('pickup_point') ??
                                'Točka ukrcaja:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        p['pickUpAddress'],
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            localizationService.translate('exit_address') ??
                                'Izlazna adresa:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        p['exitAddress'],
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await rideViewModel.approvePassenger(
                                  ride.rideId,
                                  p['userId'],
                                  true,
                                );
                              },
                              child: Text(
                                localizationService
                                        .translate('approve_passenger') ??
                                    'Prihvati putnika',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                await rideViewModel.approvePassenger(
                                  ride.rideId,
                                  p['userId'],
                                  false,
                                );
                              },
                              child: Text(
                                localizationService.translate('reject') ??
                                    'Odbij',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _setupMapData(Ride ride) async {
    final startLatLng = LatLng(
      ride.startLocation.latitude,
      ride.startLocation.longitude,
    );
    final endLatLng = LatLng(
      ride.endLocation.latitude,
      ride.endLocation.longitude,
    );

    final startMarker = Marker(
      markerId: const MarkerId('start'),
      position: startLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Polazište'),
    );
    final endMarker = Marker(
      markerId: const MarkerId('end'),
      position: endLatLng,
      infoWindow: const InfoWindow(title: 'Odredište'),
    );

    final newMarkers = <Marker>{};
    newMarkers.add(startMarker);
    newMarkers.add(endMarker);

    final acceptedPassengers = ride.passengerRequests
        .where((p) => p['isAccepted'] == true && p['exitLocation'] != null)
        .toList();
    final notAcceptedYet = ride.passengerRequests
        .where((p) => p['isAccepted'] == false && p['exitLocation'] != null)
        .toList();

    final newExitMarkers = <Marker>{};
    final waypoints = <LatLng>[];

    for (var req in acceptedPassengers) {
      final exitLoc = req['exitLocation'] as GeoPoint;
      final userId = req['userId'] as String;
      final exitLatLng = LatLng(exitLoc.latitude, exitLoc.longitude);

      final marker = Marker(
        markerId: MarkerId('exit_$userId'),
        position: exitLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: 'Izlaz putnika $userId',
        ),
      );
      newExitMarkers.add(marker);
      waypoints.add(exitLatLng);
    }

    for (var req in notAcceptedYet) {
      final exitLoc = req['exitLocation'] as GeoPoint;
      final userId = req['userId'] as String;
      final exitLatLng = LatLng(exitLoc.latitude, exitLoc.longitude);

      final marker = Marker(
        markerId: MarkerId('exit_request_$userId'),
        position: exitLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
        infoWindow: InfoWindow(
          title: 'Izlaz (još neodobreno) $userId',
        ),
      );
      newExitMarkers.add(marker);
      waypoints.add(exitLatLng);
    }

    final commuteService = Provider.of<CommuteService>(context, listen: false);
    final directions = await commuteService.getDirectionsPolylineWithWaypoints(
      startLatLng,
      endLatLng,
      waypoints,
    );

    if (directions.isNotEmpty &&
        (directions.toString() != _cachedDirectionPoints.toString())) {
      _directionPoints.clear();
      _directionPoints.addAll(directions);
      _cachedDirectionPoints = List.from(directions);
    }

    final allMarkers = newMarkers.union(newExitMarkers);
    final bounds = _computeBounds(allMarkers);

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _exitMarkers = newExitMarkers;
        _polylines = {};
        if (_directionPoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('gdirections'),
              color: Colors.green,
              width: 4,
              points: _directionPoints,
            ),
          );
        }
        _initialBounds = bounds;
      });

      if (_mapController != null && _initialBounds != null) {
        _mapController!.moveCamera(
          CameraUpdate.newLatLngBounds(_initialBounds!, 60),
        );
      }
    }
  }

  LatLngBounds _computeBounds(Set<Marker> allMarkers) {
    final latitudes = allMarkers.map((m) => m.position.latitude);
    final longitudes = allMarkers.map((m) => m.position.longitude);

    final south = latitudes.reduce(min);
    final north = latitudes.reduce(max);
    final west = longitudes.reduce(min);
    final east = longitudes.reduce(max);

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _showRateUserDialog(Ride ride, LocalizationService localizationService) {
    final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        double currentRating = 3.0;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                localizationService.translate('rate_driver') ??
                    'Ocijeni Vozača',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: currentRating,
                    min: 1.0,
                    max: 5.0,
                    divisions: 4,
                    label: currentRating.toString(),
                    onChanged: (value) {
                      setStateDialog(() {
                        currentRating = value;
                      });
                    },
                  ),
                  Text(
                    '${localizationService.translate('rating') ?? 'Ocjena'}: ${currentRating.toStringAsFixed(1)}',
                  ),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      labelText: localizationService.translate('comment') ??
                          'Komentar',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    localizationService.translate('cancel') ?? 'Odustani',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    rideViewModel.rateUser(
                      ride.driverId,
                      widget.userId,
                      currentRating,
                      comment: commentController.text,
                    );
                    setState(() {
                      _hasRated = true;
                    });
                    Navigator.of(context).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizationService.translate('user_rated') ??
                                'Korisnik ocijenjen!',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    localizationService.translate('rate') ?? 'Ocijeni',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }
}
