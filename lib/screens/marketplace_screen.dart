// lib/screens/marketplace_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'create_ad_screen.dart';
import 'ad_detail_screen.dart';
import 'flyers_screen.dart';
import '../widgets/map_view_screen.dart';
import 'infos/info_marketplace.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../utils/utils.dart'; // Importiramo funkciju normalizeCountryName
import 'package:url_launcher/url_launcher.dart'; // Dodano za otvaranje poveznica
import 'package:geolocator/geolocator.dart'; // Dodano za geolokaciju

class MarketplaceScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;

  const MarketplaceScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
  });

  @override
  MarketplaceScreenState createState() => MarketplaceScreenState();
}

class MarketplaceScreenState extends State<MarketplaceScreen> {
  Map<String, dynamic>? _locationData;
  String? _normalizedCountryId; // Koristit ćemo normalizirani naziv
  Position? _userPosition; // Pohranjujemo korisnikovu lokaciju
  bool _locationPermissionDenied = false; // Status dozvole

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMarketplaceInfo(context);
    });
    _fetchNormalizedCountryId(); // Dohvaćamo i postavljamo normalizirani naziv države
    _determineUserPosition(); // Pokušavamo dohvatiti korisnikovu lokaciju
  }

  Future<void> _determineUserPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Provjera je li usluga lokacije omogućena
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Lokacijska usluga nije omogućena
      setState(() {
        _locationPermissionDenied = true;
      });
      return;
    }

    // Provjera dozvola
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Dozvola je i dalje odbijena
        setState(() {
          _locationPermissionDenied = true;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Dozvola je trajno odbijena
      setState(() {
        _locationPermissionDenied = true;
      });
      return;
    }

    // Dohvat korisnikove trenutne lokacije
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = position;
      });
    } catch (e) {
      debugPrint('Error getting user location: $e');
      setState(() {
        _locationPermissionDenied = true;
      });
    }
  }

  Future<void> _fetchNormalizedCountryId() async {
    // Koristimo centraliziranu funkciju za normalizaciju
    String normalizedName = normalizeCountryName(widget.countryId);
    setState(() {
      _normalizedCountryId = normalizedName;
    });
    // Nakon postavljanja države, dohvatimo podatke o lokaciji
    await _fetchLocationData();
  }

  Future<void> _showMarketplaceInfo(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('show_marketplace_boarding') ?? true;

    if (shouldShow) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InfoMarketplaceScreen(),
        ),
      );
      await prefs.setBool('show_marketplace_boarding', false);
    }
  }

  Future<void> _fetchLocationData() async {
    if (_normalizedCountryId == null) return;

    try {
      final locationRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_normalizedCountryId) // Koristimo normalizirani naziv države
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId);

      final locationSnapshot = await locationRef.get();

      if (locationSnapshot.exists) {
        final data = locationSnapshot.data();
        if (data != null) {
          // Ako polje 'coordinates' ne postoji, stvorimo ga koristeći 'latitude' i 'longitude'
          if (!data.containsKey('coordinates') &&
              data.containsKey('latitude') &&
              data.containsKey('longitude')) {
            data['coordinates'] = {
              'lat': data['latitude'],
              'lng': data['longitude'],
            };
          }
          setState(() {
            _locationData = data;
          });
          debugPrint('Fetched coordinates: ${_locationData?['coordinates']}');
        }
      } else {
        debugPrint('Location data not found.');
      }
    } catch (e) {
      debugPrint('Error fetching location data: $e');
    }
  }

  Stream<List<DocumentSnapshot>> _getAdsInRadius(double radiusInKm) {
    if (_normalizedCountryId == null) {
      debugPrint('Normalized country ID not set.');
      return const Stream.empty();
    }

    double? refLat;
    double? refLon;

    if (_userPosition != null) {
      refLat = _userPosition!.latitude;
      refLon = _userPosition!.longitude;
    } else if (_locationData != null && _locationData!['coordinates'] != null) {
      refLat = _locationData!['coordinates']['lat'];
      refLon = _locationData!['coordinates']['lng'];
    } else {
      debugPrint('Reference coordinates not available.');
      return const Stream.empty();
    }

    double latRange = radiusInKm / 111;
    double lonRange = radiusInKm / (111 * cos(_degToRad(refLat!)));

    final currentDate = DateTime.now();

    return FirebaseFirestore.instance
        .collection('countries')
        .doc(_normalizedCountryId) // Koristimo normalizirani naziv države
        .collection('cities')
        .doc(widget.cityId)
        .collection('ads')
        .where('ended', isEqualTo: false)
        .where('endDate', isGreaterThan: Timestamp.fromDate(currentDate))
        .where('coordinates.lat', isGreaterThanOrEqualTo: refLat - latRange)
        .where('coordinates.lat', isLessThanOrEqualTo: refLat + latRange)
        .where('coordinates.lng', isGreaterThanOrEqualTo: refLon! - lonRange)
        .where('coordinates.lng', isLessThanOrEqualTo: refLon + lonRange)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
  }

  Future<void> _launchMap(
      double latitude, double longitude, String address) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapViewScreen(
          latitude: latitude,
          longitude: longitude,
          address: address,
        ),
      ),
    );
  }

  Future<void> _shareAd(Map<String, dynamic> ad) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final String text =
        '${ad['title']}\n\n${ad['description']}\n${localizationService.translate('address')}: ${ad['address']}\n';

    if (ad['imageUrl'] != null && ad['imageUrl'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(ad['imageUrl']));
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, 'shared_image.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: text);
      } catch (e) {
        debugPrint('Error sharing image: $e');
        await Share.share(text);
      }
    } else {
      await Share.share(text);
    }
  }

  void _showAdDetails(Map<String, dynamic> ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdDetailScreen(
          ad: ad,
          countryId:
              _normalizedCountryId!, // Koristimo normalizirani naziv države
          cityId: widget.cityId,
          locationId: widget.locationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    // Prikazivanje indikatora učitavanja dok se dohvaća korisnikova lokacija
    if (_normalizedCountryId == null ||
        (_userPosition == null &&
            !_locationPermissionDenied &&
            _locationData == null)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizationService.translate('marketplace')),
          actions: [
            IconButton(
              icon: Row(
                children: [
                  Image.asset(
                    'assets/images/flyers_1.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    localizationService.translate('flyers') ?? 'Flyers',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FlyersScreen(
                      countryId:
                          _normalizedCountryId!, // Koristimo normalizirani naziv države
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(localizationService.translate('marketplace') ?? 'Marketplace'),
        actions: [
          IconButton(
            icon: Row(
              children: [
                Image.asset(
                  'assets/images/flyers_1.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 5),
                Text(
                  localizationService.translate('flyers') ?? 'Flyers',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlyersScreen(
                    countryId:
                        _normalizedCountryId!, // Koristimo normalizirani naziv države
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _normalizedCountryId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<DocumentSnapshot>>(
              stream: _getAdsInRadius(50), // Radijus pretrage (u km)
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('Error loading ads: ${snapshot.error}');
                  return Center(
                    child: Text(
                      localizationService.translate('adsLoadError') ??
                          'Error loading ads',
                    ),
                  );
                }

                final ads = snapshot.data ?? [];

                // Dodatno filtriranje na klijentskoj strani
                final filteredAds = ads.where((adDoc) {
                  final ad = adDoc.data() as Map<String, dynamic>;
                  final coordinates = ad['coordinates'];
                  if (coordinates == null ||
                      coordinates['lat'] == null ||
                      coordinates['lng'] == null) {
                    return false; // Isključujemo oglase bez koordinata
                  }

                  final double adLat = coordinates['lat'];
                  final double adLon = coordinates['lng'];

                  double refLat;
                  double refLon;

                  if (_userPosition != null) {
                    refLat = _userPosition!.latitude;
                    refLon = _userPosition!.longitude;
                  } else if (_locationData != null &&
                      _locationData!['coordinates'] != null) {
                    refLat = _locationData!['coordinates']['lat'];
                    refLon = _locationData!['coordinates']['lng'];
                  } else {
                    return false;
                  }

                  final double distance = _calculateDistance(
                    refLat,
                    refLon,
                    adLat,
                    adLon,
                  );

                  return distance <=
                      50; // Filtriramo oglase unutar 50 km radijusa
                }).toList();

                if (filteredAds.isEmpty) {
                  return Center(
                    child: Text(
                      localizationService.translate('noAdsAvailable') ??
                          'No ads available in your area.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredAds.length,
                  itemBuilder: (context, index) {
                    final ad =
                        filteredAds[index].data() as Map<String, dynamic>;
                    final imageUrl = ad['imageUrl'] ?? '';
                    final title = ad['title'] ??
                        (localizationService.translate('noTitle') ??
                            'No Title');
                    final description = ad['description'] ??
                        (localizationService.translate('noDescription') ??
                            'No Description');
                    final address = ad['address'] ??
                        (localizationService.translate('noAddress') ??
                            'No Address');
                    final link = ad['link'] ?? '';
                    final startTime = ad['startTime'] ?? '';
                    final coordinates = ad['coordinates'];

                    if (coordinates == null ||
                        coordinates['lat'] == null ||
                        coordinates['lng'] == null) {
                      return const SizedBox();
                    }

                    final double adLat = coordinates['lat'];
                    final double adLon = coordinates['lng'];

                    // Izračun distance ako je korisnikova lokacija dostupna
                    String distanceText = '';
                    if (_userPosition != null) {
                      final distance = _calculateDistance(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        adLat,
                        adLon,
                      );
                      distanceText = '${distance.toStringAsFixed(2)} km';
                    }

                    // Ograničenje opisa na oko 400 znakova s "Više"
                    String truncatedDescription = description;
                    bool isTruncated = false;
                    if (description.length > 400) {
                      truncatedDescription = description.substring(0, 400);
                      isTruncated = true;
                    }

                    return GestureDetector(
                      onTap: () => _showAdDetails(ad),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          side:
                              const BorderSide(color: Colors.orange, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                imageUrl.isEmpty
                                    ? Image.asset(
                                        'assets/images/marketplace_1.jpg',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 200,
                                      )
                                    : Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 200,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Image.asset(
                                            'assets/images/marketplace_1.jpg',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 200,
                                          );
                                        },
                                      ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _launchMap(adLat, adLon, address),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.map,
                                        color: Colors.white,
                                        size: 36, // Povećana ikona
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => _shareAd(ad),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.share,
                                        color: Colors.white,
                                        size: 36, // Povećana ikona
                                      ),
                                    ),
                                  ),
                                ),
                                if (distanceText.isNotEmpty)
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        distanceText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    truncatedDescription,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (isTruncated)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Više',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  // Adresa
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 20),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          address,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Poveznica (ako nije prazna)
                                  if (link.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.link,
                                            size: 36, color: Colors.blue),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final uri = Uri.parse(link);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri,
                                                    mode: LaunchMode
                                                        .externalApplication);
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      localizationService.translate(
                                                              'cannotLaunchLink') ??
                                                          'Cannot launch the link',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Text(
                                              link,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Vrijeme početka (ako nije prazno)
                                  if (startTime.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.access_time,
                                            size: 36, color: Colors.blue),
                                        const SizedBox(width: 10),
                                        Text(
                                          startTime,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: _normalizedCountryId == null
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateAdScreen(
                      username: widget.username,
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                    ),
                  ),
                );
              },
              tooltip: localizationService.translate('createAd') ?? 'Create Ad',
              child: const Icon(Icons.add),
            ),
    );
  }
}
