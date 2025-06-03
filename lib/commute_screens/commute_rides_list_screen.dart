import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_model.dart';
import '../services/localization_service.dart';
import '../viewmodels/ride_view_model.dart';
import 'commute_create_ride_screen.dart' as createRide;
import 'commute_ride_detail_screen.dart';

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

class CommuteRidesListScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const CommuteRidesListScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _CommuteRidesListScreenState createState() => _CommuteRidesListScreenState();
}

class _CommuteRidesListScreenState extends State<CommuteRidesListScreen>
    with SingleTickerProviderStateMixin {
  double _selectedRadius = 1.0;
  GeoPoint? _userLocation;
  String? _userId;
  late TabController _tabController;

  int _driverCandies = 0;
  String _displayName = '';
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showIntroDialog();
      await _fetchUserLocation();
      await _fetchDriverData();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    setState(() {});
    if (_userLocation != null && _userId != null) {
      final rideViewModel = Provider.of<RideViewModel>(context, listen: false);
      if (_tabController.index == 0) {
        rideViewModel.initRides(_userLocation!, _selectedRadius, _userId!);
      } else if (_tabController.index == 1) {
        rideViewModel.initMyRides(_userId!);
      } else if (_tabController.index == 2) {
        rideViewModel.initHistoryRides(_userId!);
      }
    }
  }

  Future<void> _showIntroDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('shown_commute_intro') ?? false;
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    if (!shown) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localization.translate('welcome_title') ?? 'Dobrodošli!'),
          content: SingleChildScrollView(
            child: Text(localization.translate('welcome_message') ??
                'Ovdje možete dijeliti vožnju...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localization.translate('ok') ?? 'OK'),
            ),
          ],
        ),
      );
      await prefs.setBool('shown_commute_intro', true);
    }
  }

  Future<void> _fetchUserLocation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localization.translate('not_logged_in') ??
                  'Korisnik nije prijavljen!')),
        );
      });
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    localization.translate('location_services_disabled') ??
                        'Usluge lokacije nisu omogućene.')),
          );
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      localization.translate('location_permission_denied') ??
                          'Lokacijska dozvola je odbijena!')),
            );
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization
                      .translate('location_permission_permanently_denied') ??
                  'Lokacijska dozvola je trajno odbijena. Omogućite je u postavkama.'),
            ),
          );
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLocation = GeoPoint(position.latitude, position.longitude);
          _userId = currentUser.uid;
        });
        final rideViewModel =
            Provider.of<RideViewModel>(context, listen: false);

        if (_tabController.index == 0) {
          rideViewModel.initRides(_userLocation!, _selectedRadius, _userId!);
        } else if (_tabController.index == 1) {
          rideViewModel.initMyRides(_userId!);
        } else if (_tabController.index == 2) {
          rideViewModel.initHistoryRides(_userId!);
        }
        await rideViewModel.initMyRides(_userId!);
        await rideViewModel.initHistoryRides(_userId!);
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${localization.translate('location_error') ?? 'Greška prilikom dohvaćanja lokacije:'} $e')),
        );
      });
    }
  }

  Future<void> _fetchDriverData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          setState(() {
            _driverCandies =
                data['candies'] is int ? data['candies'] as int : 0;
            _displayName = data['displayName'] ?? '';
            _profileImageUrl = data['profileImageUrl'] ?? '';
          });
        }
      }
    }
  }

  Widget _buildTopFilter(LocalizationService localization) {
    if (_tabController.index != 0) {
      return const SizedBox.shrink();
    }
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.translate('show_within') ??
                          'Prikaži unutar:',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _selectedRadius,
                      min: 0.2,
                      max: 22.0,
                      divisions: 18,
                      label: '${(_selectedRadius * 1000).toInt()} m',
                      onChanged: (value) {
                        setState(() {
                          _selectedRadius = value;
                        });
                        if (_userLocation != null && _userId != null) {
                          final rideViewModel = Provider.of<RideViewModel>(
                              context,
                              listen: false);
                          rideViewModel.initRides(
                            _userLocation!,
                            _selectedRadius,
                            _userId!,
                          );
                        }
                      },
                    ),
                    Text(
                      '${(_selectedRadius * 1000).toInt()} m',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusToString(
      RideStatus status, bool iFinished, LocalizationService localization) {
    if (iFinished) {
      return localization.translate('status_iFinished') ?? "Izašao";
    }
    switch (status) {
      case RideStatus.requested:
        return localization.translate('status_requested') ?? 'Zatražena';
      case RideStatus.active:
        return localization.translate('status_active') ?? 'U vožnji';
      case RideStatus.completed:
        return localization.translate('status_completed') ?? 'Završena';
      case RideStatus.canceled:
        return localization.translate('status_canceled') ?? 'Otkazana';
      case RideStatus.open:
      default:
        return localization.translate('status_open') ?? 'Otvorena';
    }
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

  double _calculateDistance(GeoPoint start, GeoPoint userLoc) {
    final distanceInMeters = Geolocator.distanceBetween(
      userLoc.latitude,
      userLoc.longitude,
      start.latitude,
      start.longitude,
    );
    return distanceInMeters / 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    final rideViewModel = Provider.of<RideViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          _tabController.index == 0
              ? (localization.translate('available_rides') ?? 'Dostupne vožnje')
              : _tabController.index == 1
                  ? (localization.translate('active_rides') ?? 'Aktivne vožnje')
                  : (localization.translate('history') ?? 'Povijest'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => createRide.CommuteCreateRideScreen(
                    username: widget.username,
                    countryId: widget.countryId,
                    cityId: widget.cityId,
                    locationId: widget.locationId,
                  ),
                ),
              );
              if (result != null && _userLocation != null && _userId != null) {
                final rideViewModel =
                    Provider.of<RideViewModel>(context, listen: false);
                if (_tabController.index == 0) {
                  rideViewModel.initRides(
                      _userLocation!, _selectedRadius, _userId!);
                } else if (_tabController.index == 1) {
                  rideViewModel.initMyRides(_userId!);
                } else if (_tabController.index == 2) {
                  rideViewModel.initHistoryRides(_userId!);
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.directions_car_outlined),
              text: localization.translate('offers') ?? 'Ponude',
            ),
            Tab(
              icon: const Icon(Icons.directions_car),
              text: localization.translate('active') ?? 'Aktivne',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: localization.translate('history') ?? 'Povijest',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_userId != null)
            Container(
              color: Colors.green[50],
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: (_profileImageUrl.isNotEmpty &&
                            _profileImageUrl.startsWith('http'))
                        ? NetworkImage(_profileImageUrl)
                        : const AssetImage('assets/images/default_user.png')
                            as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.cake, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '$_driverCandies',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          _buildTopFilter(localization),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOffersTab(rideViewModel, localization),
                _buildActiveTab(rideViewModel, localization),
                _buildHistoryTab(rideViewModel, localization),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersTab(
      RideViewModel rideViewModel, LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_userLocation != null && _userId != null) {
          rideViewModel.initRides(_userLocation!, _selectedRadius, _userId!);
          await rideViewModel.initMyRides(_userId!);
          await rideViewModel.initHistoryRides(_userId!);
          await _fetchDriverData();
        }
      },
      child: StreamBuilder<List<Ride>>(
        stream: rideViewModel.availableRidesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              rideViewModel.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || rideViewModel.errorMessage != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                rideViewModel.errorMessage ??
                    '${localization.translate('rides_load_error')}\n'
                        '${snapshot.error ?? ''}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final rides = snapshot.data ?? [];
          final now = DateTime.now();
          final filtered = rides.where((ride) {
            if (ride.status == RideStatus.active ||
                ride.status == RideStatus.completed ||
                ride.status == RideStatus.canceled ||
                ride.departureTime.isBefore(now) ||
                ride.seatsAvailable <= ride.passengers.length) {
              return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    localization.translate('no_available_rides') ??
                        'Nema dostupnih vožnji u ovom trenutku.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final ride = filtered[index];
              return _buildRideCard(ride);
            },
          );
        },
      ),
    );
  }

  Widget _buildActiveTab(
      RideViewModel rideViewModel, LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_userId != null) {
          await rideViewModel.initMyRides(_userId!);
          await rideViewModel.initHistoryRides(_userId!);
          await _fetchDriverData();
        }
      },
      child: StreamBuilder<List<Ride>>(
        stream: rideViewModel.availableRidesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              rideViewModel.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || rideViewModel.errorMessage != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                rideViewModel.errorMessage ??
                    '${localization.translate('rides_load_error')}\n'
                        '${snapshot.error ?? ''}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final rides = snapshot.data ?? [];
          final activeRides = rides.where((ride) {
            if (ride.status != RideStatus.active) return false;
            final isDriver = ride.driverId == _userId;
            final isPassenger = ride.passengers.contains(_userId);
            if (!(isDriver || isPassenger)) return false;
            final passengerStatus = ride.passengersStatus?[_userId];
            final hasFinished =
                passengerStatus != null && passengerStatus['hasFinished'];
            if (!isDriver && hasFinished == true) {
              return false;
            }
            return true;
          }).toList();

          if (activeRides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    localization.translate('no_active_rides') ??
                        'Nema aktivnih vožnji.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: activeRides.length,
            itemBuilder: (context, index) {
              final ride = activeRides[index];
              return _buildRideCard(ride);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab(
      RideViewModel rideViewModel, LocalizationService localization) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_userId != null) {
          await rideViewModel.initHistoryRides(_userId!);
          await _fetchDriverData();
        }
      },
      child: StreamBuilder<List<Ride>>(
        stream: rideViewModel.historyRidesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              rideViewModel.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || rideViewModel.errorMessage != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                rideViewModel.errorMessage ??
                    '${localization.translate('rides_load_error')}\n'
                        '${snapshot.error ?? ''}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final rides = snapshot.data ?? [];
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    localization.translate('no_history_rides') ??
                        'Nema vožnji u povijesti.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              return _buildRideCard(ride);
            },
          );
        },
      ),
    );
  }

  Widget _buildRideCard(Ride ride) {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    final now = DateTime.now();
    final passengerStatus = ride.passengersStatus?[_userId ?? ''];
    final hasFinishedForMe =
        passengerStatus != null && passengerStatus['hasFinished'] == true;

    if (_tabController.index == 0) {
      if (ride.status == RideStatus.active ||
          ride.status == RideStatus.completed ||
          ride.status == RideStatus.canceled ||
          ride.departureTime.isBefore(now) ||
          ride.seatsAvailable <= ride.passengers.length) {
        return const SizedBox.shrink();
      }
    }

    if (_tabController.index == 1) {
      if (ride.status != RideStatus.active) {
        return const SizedBox.shrink();
      }
      final isDriver = ride.driverId == _userId;
      if (!isDriver && !ride.passengers.contains(_userId!)) {
        return const SizedBox.shrink();
      }
      if (!isDriver && hasFinishedForMe) {
        return const SizedBox.shrink();
      }
    }

    if (_tabController.index == 2) {
      final isDone = (ride.status == RideStatus.completed ||
          ride.status == RideStatus.canceled);
      final isPast = ride.departureTime.isBefore(now);
      if (!(isDone || isPast || hasFinishedForMe)) {
        return const SizedBox.shrink();
      }
    }

    final dist = (_userLocation != null)
        ? _calculateDistance(ride.startLocation, _userLocation!)
        : 0.0;
    final distKm = dist.toStringAsFixed(1);
    final isDriver = (_userId != null && _userId == ride.driverId);
    final tileColor = (ride.status == RideStatus.canceled)
        ? Colors.red[100]
        : (isDriver ? Colors.green[50] : Colors.white);

    ImageProvider driverImage;
    if (ride.driverPhotoUrl.isNotEmpty &&
        ride.driverPhotoUrl.startsWith('http')) {
      driverImage = NetworkImage(ride.driverPhotoUrl);
    } else {
      driverImage = const AssetImage('assets/images/default_user.png');
    }

    final showLocalFinished =
        hasFinishedForMe && ride.status == RideStatus.active;
    final displayStatus =
        _statusToString(ride.status, showLocalFinished, localization);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      color: tileColor,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommuteRideDetailScreen(
                    rideId: ride.rideId,
                    userId: _userId ?? '',
                  ),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.all(8.0),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drive_eta, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: driverImage,
                  ),
                ],
              ),
              title: Text(
                ride.driverName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prikaz polazišta
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ride.startAddress,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Prikaz odredišta
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ride.endAddress,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Prikaz vremena polaska
                    Text(
                      '${localization.translate('departure_time') ?? 'Vrijeme polaska:'} ${DateFormat('dd.MM.yyyy. HH:mm').format(ride.departureTime)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),

                    // Status
                    Row(
                      children: [
                        Text(
                          '${localization.translate('status') ?? 'Status:'} $displayStatus',
                          style: TextStyle(
                            fontSize: 13,
                            color: _statusColor(ride.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ride.status == RideStatus.active) ...[
                          const SizedBox(width: 6),
                          const BlinkingIcon(
                            icon: Icons.circle,
                            color: Colors.green,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$distKm km',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Icon(Icons.location_on, color: Colors.red, size: 16),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: _buildRideMiniMap(ride),
          ),
        ],
      ),
    );
  }

  Widget _buildRideMiniMap(Ride ride) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rideshare')
          .doc(ride.rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }
        final updatedRide = Ride.fromFirestore(snapshot.data!);
        final markers = <Marker>{};
        if (updatedRide.startLocation.latitude != 0) {
          markers.add(
            Marker(
              markerId: const MarkerId('start-mini'),
              position: LatLng(
                updatedRide.startLocation.latitude,
                updatedRide.startLocation.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            ),
          );
        }
        if (updatedRide.endLocation.latitude != 0) {
          markers.add(
            Marker(
              markerId: const MarkerId('end-mini'),
              position: LatLng(
                updatedRide.endLocation.latitude,
                updatedRide.endLocation.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
            ),
          );
        }
        final polylines = <Polyline>{};
        if (updatedRide.route.isNotEmpty) {
          final routeCoords = updatedRide.route.map((gp) {
            return LatLng(gp.latitude, gp.longitude);
          }).toList();
          polylines.add(
            Polyline(
              polylineId: const PolylineId('mini-route'),
              color: Colors.blue,
              width: 3,
              points: routeCoords,
            ),
          );
        }
        final passengerExits = updatedRide.passengerRequests
            .where((p) => p['isAccepted'] == true && p['exitLocation'] != null)
            .toList();
        for (var ex in passengerExits) {
          GeoPoint eLoc = ex['exitLocation'];
          markers.add(
            Marker(
              markerId: MarkerId('exit-mini-${ex['userId']}'),
              position: LatLng(eLoc.latitude, eLoc.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
            ),
          );
        }

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              updatedRide.startLocation.latitude,
              updatedRide.startLocation.longitude,
            ),
            zoom: 7,
          ),
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 300), () async {
                final latLngs = markers.map((m) => m.position).toList();
                if (latLngs.isNotEmpty) {
                  double minLat = latLngs.first.latitude;
                  double maxLat = latLngs.first.latitude;
                  double minLng = latLngs.first.longitude;
                  double maxLng = latLngs.first.longitude;
                  for (var pos in latLngs) {
                    if (pos.latitude < minLat) minLat = pos.latitude;
                    if (pos.latitude > maxLat) maxLat = pos.latitude;
                    if (pos.longitude < minLng) minLng = pos.longitude;
                    if (pos.longitude > maxLng) maxLng = pos.longitude;
                  }
                  final bounds = LatLngBounds(
                    southwest: LatLng(minLat, minLng),
                    northeast: LatLng(maxLat, maxLng),
                  );
                  try {
                    await controller.animateCamera(
                        CameraUpdate.newLatLngBounds(bounds, 30));
                  } catch (_) {}
                }
              });
            });
          },
        );
      },
    );
  }
}
