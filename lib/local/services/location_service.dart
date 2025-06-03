// lib/services/location_service.dart

import 'dart:convert';
import 'dart:math';
import 'dart:collection'; // Za keširanje
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../services/localization_service.dart'; // Import za lokalizaciju

import '../constants/location_constants.dart'; // NOVI import za konstante

class LocationService {
  final String apiKey =
      'AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM'; // Ovdje stavite Vaš Google Geocoding API ključ

  Map<String, List<String>> _neighborhoods = {};
  final Map<String, String> _geocodeCache =
      HashMap(); // Keš za rezultate geokodiranja

  LocationService() {
    _loadNeighborhoods();
  }

  Future<void> _loadNeighborhoods() async {
    try {
      String data = await rootBundle.loadString('assets/neighborhoods.json');
      final Map<String, dynamic> jsonResult = json.decode(data);

      _neighborhoods = jsonResult.map((key, value) {
        return MapEntry(key, List<String>.from(value));
      });

      debugPrint("Neighborhoods loaded: $_neighborhoods");
    } catch (e) {
      debugPrint("Error loading neighborhoods: $e");
    }
  }

  Future<Map<String, String>> getGeographicalData(
      double lat, double lng) async {
    final localizationService = LocalizationService.instance;
    final cacheKey = '$lat,$lng';

    // Provjera keša prije slanja zahtjeva
    if (_geocodeCache.containsKey(cacheKey)) {
      debugPrint("Returning cached geocode data for $cacheKey");
      final cachedData = json.decode(_geocodeCache[cacheKey]!);
      return {
        'country': cachedData['country'] ?? LocationConstants.UNKNOWN_COUNTRY,
        'city': cachedData['city'] ?? LocationConstants.UNKNOWN_CITY,
        'neighborhood': cachedData['neighborhood'] ??
            LocationConstants.UNKNOWN_NEIGHBORHOOD,
        'username':
            cachedData['username'] ?? localizationService.translate('user'),
      };
    }

    try {
      final geoData = await _getGeocodeData(lat, lng);

      String country = geoData['country'] ?? LocationConstants.UNKNOWN_COUNTRY;
      String city = geoData['city'] ?? LocationConstants.UNKNOWN_CITY;
      String neighborhood =
          geoData['neighborhood'] ?? LocationConstants.UNKNOWN_NEIGHBORHOOD;

      // Pokušaj pronalaska poklapanja naselja iz JSON datoteke
      String matchedNeighborhood =
          _getMatchedNeighborhood(city, geoData['allNeighborhoods'] ?? []);

      // Keširanje rezultata
      _geocodeCache[cacheKey] = json.encode({
        'country': country,
        'city': city,
        'neighborhood':
            matchedNeighborhood.isNotEmpty ? matchedNeighborhood : neighborhood,
        'username': 'Korisnik' // Lokalizirano tek pri prikazu u UI
      });

      return {
        'country': country,
        'city': city,
        'neighborhood':
            matchedNeighborhood.isNotEmpty ? matchedNeighborhood : neighborhood,
        'username': 'Korisnik',
      };
    } catch (e) {
      debugPrint("Error getting geographical data: $e");
      return {
        'country': LocationConstants.UNKNOWN_COUNTRY,
        'city': LocationConstants.UNKNOWN_CITY,
        'neighborhood': LocationConstants.UNKNOWN_NEIGHBORHOOD,
      };
    }
  }

  Future<Map<String, dynamic>> _getGeocodeData(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;

      String country = LocationConstants.UNKNOWN_COUNTRY;
      String city = LocationConstants.UNKNOWN_CITY;
      String neighborhood = LocationConstants.UNKNOWN_NEIGHBORHOOD;
      List<String> allNeighborhoods = [];

      if (results.isNotEmpty) {
        for (var result in results) {
          final addressComponents =
              result['address_components'] as List<dynamic>;

          for (var component in addressComponents) {
            final types = component['types'] as List<dynamic>;

            if (types.contains('country')) {
              country = component['long_name'];
            } else if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('neighborhood') ||
                types.contains('sublocality_level_1') ||
                types.contains('sublocality') ||
                types.contains('route')) {
              neighborhood = component['long_name'];
              allNeighborhoods.add(component['long_name']);
            }
          }
        }
      }

      return {
        'country': country,
        'city': city,
        'neighborhood': neighborhood,
        'allNeighborhoods': allNeighborhoods,
      };
    } else {
      debugPrint('Geocode Error: ${response.body}');
      throw Exception('Failed to get geographical data');
    }
  }

  String _getMatchedNeighborhood(
      String city, List<String> detectedNeighborhoods) {
    // Pokušavamo pronaći prvo poklapanje u popisu naselja za taj grad.
    List<String> cityNeighborhoods = _neighborhoods[city] ?? [];

    for (String detected in detectedNeighborhoods) {
      for (String neighborhood in cityNeighborhoods) {
        if (detected.toLowerCase().contains(neighborhood.toLowerCase())) {
          return neighborhood;
        }
      }
    }

    return "";
  }

  /// Dohvat postova za određeni grad
  Query getCityPostsQuery(String countryId, String cityId) {
    return FirebaseFirestore.instance
        .collectionGroup('posts')
        .where('localCityId', isEqualTo: cityId)
        .where('localCountryId', isEqualTo: countryId)
        .orderBy('createdAt', descending: true);
  }

  /// Dohvat postova za određeni kvart
  Query getPostsQuery(
    String countryId,
    String cityId,
    String neighborhoodId, {
    String? username,
  }) {
    var query = FirebaseFirestore.instance
        .collection('local_community')
        .doc(countryId)
        .collection('cities')
        .doc(cityId)
        .collection('neighborhoods')
        .doc(neighborhoodId)
        .collection('posts')
        .orderBy('createdAt', descending: true);

    // Ako je korisnik anoniman, preskačemo filtriranje po imenu
    if (username != null &&
        username != LocalizationService.instance.translate('anonymous')) {
      query = query.where('username', isEqualTo: username);
    }

    return query;
  }

  /// Grupiranje postova po lokaciji i vremenu
  List<List<Map<String, dynamic>>> groupPostsByLocationAndTime(
      List<Map<String, dynamic>> posts) {
    const double maxDistanceInMeters = 500.0;
    const int maxTimeDifferenceInMinutes = 30;

    List<List<Map<String, dynamic>>> groupedPosts = [];

    for (var post in posts) {
      bool addedToGroup = false;

      for (var group in groupedPosts) {
        var firstPostInGroup = group.first;
        double distance = _calculateDistance(
          post['postGeoLocation'],
          firstPostInGroup['postGeoLocation'],
        );
        int timeDifference = _calculateTimeDifference(
          post['createdAt'],
          firstPostInGroup['createdAt'],
        );

        if (distance <= maxDistanceInMeters &&
            timeDifference <= maxTimeDifferenceInMinutes) {
          group.add(post);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groupedPosts.add([post]);
      }
    }

    return groupedPosts;
  }

  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    const double radiusOfEarth = 6371000; // u metrima

    double lat1 = point1.latitude * pi / 180;
    double lon1 = point1.longitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double lon2 = point2.longitude * pi / 180;

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return radiusOfEarth * c;
  }

  int _calculateTimeDifference(Timestamp time1, Timestamp time2) {
    return time1.toDate().difference(time2.toDate()).inMinutes.abs();
  }
}
