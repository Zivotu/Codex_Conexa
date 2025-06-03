import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import '../models/ride_model.dart';
import '../services/commute_service.dart';
import '../services/user_service.dart';

class ActiveRideMapScreen extends StatefulWidget {
  final String rideId;
  const ActiveRideMapScreen({super.key, required this.rideId});

  @override
  ActiveRideMapScreenState createState() => ActiveRideMapScreenState();
}

class ActiveRideMapScreenState extends State<ActiveRideMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _driverLatLng;
  final Map<String, LatLng> _allPassengerLatLngs = {};
  LatLng? _destinationLatLng;

  /// Ikona automobila za vozača
  BitmapDescriptor? _carIcon;

  /// Profilne slike putnika
  final Map<String, BitmapDescriptor> _userIcons = {};

  StreamSubscription<QuerySnapshot>? _driverLocationSub;
  final List<StreamSubscription<QuerySnapshot>> _allPassengersSubs = [];
  StreamSubscription<Position>? _positionSubscription;

  bool _isDriver = false;
  bool _hasFinishedForThisPassenger = false;

  /// Ako je `_isSharingLocation = false` za putnika, tada ga drugi NE vide na mapi.
  bool _isSharingLocation = false;

  List<LatLng> _driverRoutePoints = [];
  final Map<String, List<LatLng>> _passengersRoutePoints = {};

  double _currentZoom = 16;
  String? _driverUserId;

  /// Keš user dokumenata za prikaz profilnih fotki (npr. gore desno)
  final Map<String, Map<String, dynamic>> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _fetchRideData();
  }

  Future<void> _loadCarIcon() async {
    final ByteData bytes = await rootBundle.load('assets/images/car_icon.png');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 80, // Samo širina
      // targetHeight nije postavljen kako bi se zadržao aspektni odnos
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      setState(() {
        _carIcon = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      });
    }
  }

  Future<void> _fetchRideData() async {
    final rideDoc = await FirebaseFirestore.instance
        .collection('rideshare')
        .doc(widget.rideId)
        .get();
    if (!rideDoc.exists) return;

    final ride = Ride.fromFirestore(rideDoc);
    _isDriver = (ride.driverId == FirebaseAuth.instance.currentUser?.uid);
    _driverUserId = ride.driverId;

    final passengerStatus =
        ride.passengersStatus?[FirebaseAuth.instance.currentUser?.uid];
    _hasFinishedForThisPassenger =
        passengerStatus != null && passengerStatus['hasFinished'] == true;

    if (ride.endLocation.latitude != 0) {
      _destinationLatLng =
          LatLng(ride.endLocation.latitude, ride.endLocation.longitude);
    }

    // Učitaj podatke vozača i svih putnika da bi imali npr. profileImageUrl
    await _fetchUserProfile(ride.driverId);
    for (final p in ride.passengers) {
      await _fetchUserProfile(p);
    }

    final commuteService = Provider.of<CommuteService>(context, listen: false);

    // Stream za driver route
    commuteService.getDriverRouteStream(widget.rideId).listen((geoPoints) {
      if (mounted) {
        setState(() {
          final points =
              geoPoints.map((g) => LatLng(g.latitude, g.longitude)).toList();
          if (points.length > 300) {
            points.removeRange(0, points.length - 300);
          }
          _driverRoutePoints = points;
        });
        _updatePolylines();
      }
    });

    if (_isDriver) {
      // Vozač sluša sve putnike
      _subscribeToAllPassengers(ride);
    } else {
      // Putnik sluša samo svoju lokaciju + sve putnike
      _subscribeToPassengerLocation(FirebaseAuth.instance.currentUser!.uid);
      _subscribeToAllPassengers(ride);
    }

    // Sluša se i vozačeva lokacija
    _subscribeToDriverLocation();
  }

  Future<void> _fetchUserProfile(String userId) async {
    if (_userProfiles.containsKey(userId)) return;
    final userService = Provider.of<UserService>(context, listen: false);
    final doc = await userService.getUserDocumentById(userId);
    if (doc != null) {
      _userProfiles[userId] = doc;
    }
  }

  Future<void> _subscribeToAllPassengers(Ride ride) async {
    for (var sub in _allPassengersSubs) {
      sub.cancel();
    }
    _allPassengersSubs.clear();

    for (String passengerId in ride.passengers) {
      final sub = FirebaseFirestore.instance
          .collection('rideshare')
          .doc(widget.rideId)
          .collection('tracking')
          .doc('passengers')
          .collection(passengerId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first.data();
          if (doc['location'] != null) {
            GeoPoint gp = doc['location'];
            setState(() {
              _allPassengerLatLngs[passengerId] =
                  LatLng(gp.latitude, gp.longitude);
            });
            _updateMarkers();
          }
        }
        final routePoints = snapshot.docs
            .map((e) {
              final loc = e['location'] as GeoPoint?;
              if (loc == null) return null;
              return LatLng(loc.latitude, loc.longitude);
            })
            .where((element) => element != null)
            .cast<LatLng>()
            .toList();
        if (routePoints.length > 300) {
          routePoints.removeRange(0, routePoints.length - 300);
        }
        setState(() {
          _passengersRoutePoints[passengerId] = routePoints;
        });
        _updatePolylines();
      });
      _allPassengersSubs.add(sub);
    }
  }

  Future<void> _subscribeToPassengerLocation(String passengerId) async {
    final passengerCollection = FirebaseFirestore.instance
        .collection('rideshare')
        .doc(widget.rideId)
        .collection('tracking')
        .doc('passengers')
        .collection(passengerId);

    final sub = passengerCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first.data();
        if (doc['location'] != null) {
          GeoPoint gp = doc['location'];
          setState(() {
            _allPassengerLatLngs[passengerId] =
                LatLng(gp.latitude, gp.longitude);
          });
          _updateMarkers();
        }
      }
      final routePoints = snapshot.docs
          .map((e) {
            final loc = e['location'] as GeoPoint?;
            if (loc == null) return null;
            return LatLng(loc.latitude, loc.longitude);
          })
          .where((element) => element != null)
          .cast<LatLng>()
          .toList();
      if (routePoints.length > 300) {
        routePoints.removeRange(0, routePoints.length - 300);
      }
      setState(() {
        _passengersRoutePoints[passengerId] = routePoints;
      });
      _updatePolylines();
    });
    _allPassengersSubs.add(sub);
  }

  Future<void> _subscribeToDriverLocation() async {
    _driverLocationSub?.cancel();
    final trackingRef = FirebaseFirestore.instance
        .collection('rideshare')
        .doc(widget.rideId)
        .collection('tracking')
        .doc('driver')
        .collection('route');

    _driverLocationSub = trackingRef
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first.data();
        if (doc['location'] != null) {
          GeoPoint gp = doc['location'];
          setState(() {
            _driverLatLng = LatLng(gp.latitude, gp.longitude);
          });
          _updateMarkers();
        }
      }
    });
  }

  List<LatLng> _filterRouteByDistance(
      List<LatLng> points, double maxDistanceMeters) {
    if (points.isEmpty) return [];

    List<LatLng> filtered = [];
    double accumulatedDistance = 0.0;

    // Počnite od posljednje točke i idite unazad
    for (int i = points.length - 1; i >= 0; i--) {
      if (filtered.isNotEmpty) {
        double distance = Geolocator.distanceBetween(
          points[i].latitude,
          points[i].longitude,
          filtered.last.latitude,
          filtered.last.longitude,
        );
        accumulatedDistance += distance;

        if (accumulatedDistance > maxDistanceMeters) {
          break;
        }
      }
      filtered.add(points[i]);
    }

    // Obrnuti listu kako bi bila ispravno u kronološkom redu
    return filtered.reversed.toList();
  }

  @override
  void dispose() {
    _driverLocationSub?.cancel();
    for (var sub in _allPassengersSubs) {
      sub.cancel();
    }
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Osvježavanje markera na karti
  /// - Vozač = car_icon.png
  /// - Putnici = profilna slika (samo ako dijele lokaciju ili ako su to "ja" u svom prikazu)
  /// - Odredište = crveni marker
  void _updateMarkers() async {
    _markers.clear();

    // Marker vozača
    if (_driverLatLng != null) {
      final driverIcon = _carIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLatLng!,
          icon: driverIcon,
          infoWindow: const InfoWindow(title: 'Vozač'),
        ),
      );
    }

    // Putnici
    final myId = FirebaseAuth.instance.currentUser!.uid;
    _allPassengerLatLngs.forEach((passengerId, latLng) async {
      bool showMarkerToOthers = false;
      if (passengerId == myId) {
        showMarkerToOthers = true; // Ja sebe uvijek vidim
      } else {
        // putnik je tu => dijeli
        showMarkerToOthers = true;
      }

      if (showMarkerToOthers) {
        if (!_userIcons.containsKey(passengerId)) {
          // Napravi profilnu sliku
          final icon = await _createUserIcon(passengerId);
          _userIcons[passengerId] = icon;
        }
        final passengerIcon = _userIcons[passengerId] ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            );
        _markers.add(
          Marker(
            markerId: MarkerId('passenger-$passengerId'),
            position: latLng,
            icon: passengerIcon,
            infoWindow: InfoWindow(title: 'Putnik $passengerId'),
          ),
        );
      }
    });

    // Odredište
    if (_destinationLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Odredište'),
        ),
      );
    }

    setState(() {});
  }

  /// Kreira bitmapu iz profilne fotke korisnika.
  Future<BitmapDescriptor> _createUserIcon(String userId) async {
    try {
      final userDoc = _userProfiles[userId];
      final profileImageUrl = userDoc?['profileImageUrl'] as String?;

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        ui.Codec codec;
        if (profileImageUrl.startsWith('http')) {
          final byteData =
              await NetworkAssetBundle(Uri.parse(profileImageUrl)).load("");
          codec = await ui.instantiateImageCodec(
            byteData.buffer.asUint8List(),
            targetWidth: 100, // Samo širina
            // targetHeight nije postavljen
          );
        } else {
          // Ako je to lokalna putanja
          final ByteData bytes = await rootBundle.load(profileImageUrl);
          codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
            targetWidth: 100, // Samo širina
            // targetHeight nije postavljen
          );
        }
        final frame = await codec.getNextFrame();
        final data =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          return BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange);
        }
        return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      } else {
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange);
      }
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// Ažurira polilinije vozača i putnika (posljednjih 300 točaka).
  void _updatePolylines() {
    _polylines.clear();

    const double maxDistanceMeters = 300.0; // 300 metara

    // Ruta vozača
    if (_driverRoutePoints.length >= 2) {
      List<LatLng> filteredDriverRoute =
          _filterRouteByDistance(_driverRoutePoints, maxDistanceMeters);
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driverRoute'),
          color: Colors.blue,
          width: 5,
          points: filteredDriverRoute,
        ),
      );
    }

    // Rute putnika
    _passengersRoutePoints.forEach((passengerId, routeList) {
      if (routeList.length >= 2) {
        List<LatLng> filteredPassengerRoute =
            _filterRouteByDistance(routeList, maxDistanceMeters);
        _polylines.add(
          Polyline(
            polylineId: PolylineId('passenger-$passengerId'),
            color: Colors.purple,
            width: 5,
            points: filteredPassengerRoute,
          ),
        );
      }
    });

    setState(() {});
  }

  /// Vozač započinje slanje lokacije
  void _startPositionStreamForDriver() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      final newGeoPoint = GeoPoint(position.latitude, position.longitude);
      final commuteService =
          Provider.of<CommuteService>(context, listen: false);
      await commuteService.startTrackingLocation(
        widget.rideId,
        newGeoPoint,
        isPassenger: false,
      );
    });
  }

  /// Putnik započinje slanje lokacije
  void _startPositionStreamForPassenger() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      final newGeoPoint = GeoPoint(position.latitude, position.longitude);
      final commuteService =
          Provider.of<CommuteService>(context, listen: false);
      await commuteService.startTrackingLocation(
        widget.rideId,
        newGeoPoint,
        isPassenger: true,
        passengerId: FirebaseAuth.instance.currentUser!.uid,
      );
    });
  }

  /// Putnik postavlja trenutnu lokaciju i počinje dijeliti
  Future<void> _setMyCurrentLocationAsPassenger() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usluge lokacije nisu omogućene.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokacijske dozvole odbijene.')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Lokacijske dozvole trajno odbijene. Omogući ručno.')),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final newGeoPoint = GeoPoint(pos.latitude, pos.longitude);

    final commuteService = Provider.of<CommuteService>(context, listen: false);
    await commuteService.startTrackingLocation(
      widget.rideId,
      newGeoPoint,
      isPassenger: true,
      passengerId: FirebaseAuth.instance.currentUser!.uid,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Postavljena Vaša trenutna lokacija!')),
    );

    _isSharingLocation = true;
    _startPositionStreamForPassenger();
  }

  @override
  Widget build(BuildContext context) {
    // Ako je putniku vožnja završena, prikazujemo samo poruku
    if (!_isDriver && _hasFinishedForThisPassenger) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Aktivna vožnja'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text(
            'Završili ste ovu vožnju. Ne možete više pratiti.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    // Ako je vozač i nije još pokrenuo dijeljenje, pokreni automatski
    if (_isDriver && !_isSharingLocation) {
      _isSharingLocation = true;
      _startPositionStreamForDriver();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivna vožnja'),
        backgroundColor: Colors.green,
        actions: [
          _buildSharingUsersAvatars(),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(45.8150, 15.9819),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), () {
                _onCenterPressed();
              });
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            right: 10,
            bottom: 110,
            child: Column(
              children: [
                if (!_isDriver && !_hasFinishedForThisPassenger)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: FloatingActionButton.extended(
                      heroTag: "btn1",
                      backgroundColor: Colors.blueAccent,
                      onPressed: _setMyCurrentLocationAsPassenger,
                      label: const Text("Lokacija",
                          style: TextStyle(fontSize: 12)),
                      icon: const Icon(Icons.my_location, size: 18),
                    ),
                  ),
                FloatingActionButton.extended(
                  heroTag: "btn2",
                  backgroundColor: Colors.blueGrey,
                  onPressed: _onCenterPressed,
                  label: const Text("Centar", style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                ),
                const SizedBox(height: 8),
                if (!_isDriver && !_hasFinishedForThisPassenger)
                  FloatingActionButton.extended(
                    heroTag: "btn3",
                    backgroundColor:
                        _isSharingLocation ? Colors.red : Colors.green,
                    onPressed: () async {
                      setState(() {
                        _isSharingLocation = !_isSharingLocation;
                      });
                      if (_isSharingLocation) {
                        _startPositionStreamForPassenger();
                      } else {
                        // ***** DODANO: Gasimo slanje lokacije i brišemo iz Firestore-a *****
                        _positionSubscription?.cancel();
                        final commuteService = Provider.of<CommuteService>(
                          context,
                          listen: false,
                        );
                        await commuteService.stopTrackingLocation(
                          widget.rideId,
                          FirebaseAuth.instance.currentUser!.uid,
                        );
                        // Ukloni ga iz lokalnih struktura
                        _allPassengerLatLngs
                            .remove(FirebaseAuth.instance.currentUser!.uid);
                        _userIcons
                            .remove(FirebaseAuth.instance.currentUser!.uid);
                        _updateMarkers();
                        _updatePolylines();
                      }
                    },
                    label: _isSharingLocation
                        ? const Text("Stop", style: TextStyle(fontSize: 12))
                        : const Text("Dijeli", style: TextStyle(fontSize: 12)),
                    icon: const Icon(Icons.share_location, size: 18),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      backgroundColor: Colors.white,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      backgroundColor: Colors.white,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vraća listu avatara korisnika (vozač + putnici koji dijele lokaciju).
  Widget _buildSharingUsersAvatars() {
    final userIds = <String>[];
    // Dodaj vozača ako ima lokaciju
    if (_driverLatLng != null && _driverUserId != null) {
      userIds.add(_driverUserId!);
    }
    // Dodaj sve putnike koji dijele lokaciju
    for (var key in _allPassengerLatLngs.keys) {
      userIds.add(key);
    }
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: uniqueIds.map((id) {
        final doc = _userProfiles[id];
        final profileImageUrl = doc?['profileImageUrl'] as String?;
        return InkWell(
          onTap: () {
            _centerOnUser(id);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message: doc?['displayName'] ?? id,
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                    (profileImageUrl != null && profileImageUrl.isNotEmpty)
                        ? (profileImageUrl.startsWith('http')
                            ? NetworkImage(profileImageUrl)
                            : AssetImage(profileImageUrl) as ImageProvider)
                        : null,
                child: (profileImageUrl == null || profileImageUrl.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Colors.grey)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _centerOnUser(String userId) {
    if (userId == _driverUserId) {
      if (_driverLatLng != null) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _driverLatLng!, zoom: _currentZoom),
          ),
        );
      }
      return;
    }
    final latLng = _allPassengerLatLngs[userId];
    if (latLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: _currentZoom),
        ),
      );
    }
  }

  void _onCenterPressed() {
    if (_isDriver && _driverLatLng != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLatLng!, zoom: _currentZoom),
        ),
      );
    } else {
      final me = _allPassengerLatLngs[FirebaseAuth.instance.currentUser!.uid];
      if (me != null) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: me, zoom: _currentZoom),
          ),
        );
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = min(_currentZoom + 1, 20);
    });
    _onCenterPressed();
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = max(_currentZoom - 1, 1);
    });
    _onCenterPressed();
  }
}
