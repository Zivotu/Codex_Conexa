import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/localization_service.dart'; // Import lokalizacije

Future<String> getCurrentNeighborhood(
    {bool isAnonymous = false,
    required LocalizationService localizationService}) async {
  // Provjerite je li usluga lokacije omogućena i zatražite dozvole
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return localizationService.translate('unknown_neighborhood');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return localizationService.translate('unknown_neighborhood');
    }
  }

  try {
    // Dobijte trenutnu lokaciju
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    double latitude = position.latitude;
    double longitude = position.longitude;

    // Dobijte adresu koristeći geocoding
    final placemark = await getAddressFromLatLng(latitude, longitude);

    // Ako je anonimni način aktivan, vraćamo generičke podatke
    if (isAnonymous) {
      return localizationService.translate('anonymous_neighborhood');
    }

    return placemark.subLocality ??
        localizationService.translate('unknown_neighborhood');
  } catch (e) {
    return localizationService.translate('unknown_neighborhood');
  }
}

Future<Placemark> getAddressFromLatLng(
    double latitude, double longitude) async {
  List<Placemark> placemarks =
      await placemarkFromCoordinates(latitude, longitude);
  if (placemarks.isNotEmpty) {
    return placemarks.first;
  } else {
    throw Exception('No address found');
  }
}
