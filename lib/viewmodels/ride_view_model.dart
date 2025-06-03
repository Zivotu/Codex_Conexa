import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import '../services/commute_service.dart';
import '../services/user_service.dart';
import '../models/ride_model.dart';

class RideViewModel extends ChangeNotifier {
  final CommuteService _commuteService;
  final UserService _userService;
  final Logger _logger = Logger();

  final BehaviorSubject<List<Ride>> _availableRidesSubject =
      BehaviorSubject<List<Ride>>();
  Stream<List<Ride>> get availableRidesStream => _availableRidesSubject.stream;

  final BehaviorSubject<List<Ride>> _myRidesSubject =
      BehaviorSubject<List<Ride>>();
  Stream<List<Ride>> get myRidesStream => _myRidesSubject.stream;

  final BehaviorSubject<List<Ride>> _historyRidesSubject =
      BehaviorSubject<List<Ride>>();
  Stream<List<Ride>> get historyRidesStream => _historyRidesSubject.stream;

  bool isLoading = false;
  String? errorMessage;

  // Po defaultu, sortiramo po vremenu polaska.
  String _currentSortOption = 'departureTime';
  int _minSeatsAvailable = 1;

  RideViewModel({
    required CommuteService commuteService,
    required UserService userService,
  })  : _commuteService = commuteService,
        _userService = userService;

  Future<void> initRides(
    GeoPoint userLocation,
    double radiusInKm,
    String userId,
  ) async {
    isLoading = true;
    notifyListeners();
    try {
      final rides = await _commuteService.getAvailableRides(
        userLocation,
        radiusInKm,
        userId,
      );
      final validRides = rides
          .where((r) =>
              r.status != RideStatus.canceled &&
              r.status != RideStatus.completed &&
              (r.departureTime.isAfter(DateTime.now()) ||
                  r.passengers.contains(userId)) &&
              (r.seatsAvailable >= _minSeatsAvailable ||
                  r.passengers.contains(userId)))
          .toList();

      _sortRides(validRides);
      _availableRidesSubject.add(validRides);
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Greška prilikom inicijalizacije vožnji: ${e.toString()}';
      _logger.e(errorMessage);
      _availableRidesSubject.addError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initMyRides(String userId) async {
    isLoading = true;
    notifyListeners();
    try {
      _commuteService.getMyRides(userId).listen((rides) {
        rides.sort((a, b) => a.departureTime.compareTo(b.departureTime));
        _myRidesSubject.add(rides);
      }, onError: (error) {
        errorMessage = 'Greška: $error';
        _logger.e(errorMessage);
        _myRidesSubject.addError(error);
      });
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Greška: $e';
      _logger.e(errorMessage);
      _myRidesSubject.addError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initHistoryRides(String userId) async {
    isLoading = true;
    notifyListeners();
    try {
      _commuteService.getHistoryRides(userId).listen((rides) {
        rides.sort((a, b) => b.departureTime.compareTo(a.departureTime));
        _historyRidesSubject.add(rides);
      }, onError: (error) {
        errorMessage = 'Greška: $error';
        _logger.e(errorMessage);
        _historyRidesSubject.addError(error);
      });
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Greška: $e';
      _logger.e(errorMessage);
      _historyRidesSubject.addError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setMinSeatsAvailable(int minSeats) {
    _minSeatsAvailable = minSeats;
    notifyListeners();
  }

  void setSortOption(String sortOption) {
    _currentSortOption = sortOption;
    notifyListeners();
  }

  void _sortRides(List<Ride> rides) {
    switch (_currentSortOption) {
      case 'departureTime':
        // Sortiramo uzlazno po vremenu polaska (najbliže sadašnjem vremenu su prvo).
        rides.sort((a, b) => a.departureTime.compareTo(b.departureTime));
        break;
      case 'seatsAvailable':
        // Ako želite sortirati npr. po broju slobodnih mjesta.
        rides.sort((a, b) => b.seatsAvailable.compareTo(a.seatsAvailable));
        break;
      default:
        rides.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    }
  }

  Future<void> createRide(Ride ride) async {
    try {
      isLoading = true;
      notifyListeners();
      final userDoc = await _userService.getUserDocumentById(ride.driverId);
      String driverName = userDoc?['displayName'] ?? 'Nepoznati vozač';
      String driverPhotoUrl = userDoc?['profileImageUrl'] ?? '';

      final rideWithDriverData = ride.copyWith(
        driverName: driverName,
        driverPhotoUrl: driverPhotoUrl,
        createdAt: Timestamp.now(),
      );
      await _commuteService.createRide(rideWithDriverData);
      errorMessage = null;
      _logger.d("Vožnja kreirana: ${rideWithDriverData.rideId}");
    } catch (e) {
      errorMessage = 'Neuspješno kreiranje vožnje: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinRide(String rideId, String userId,
      {GeoPoint? exitLocation}) async {
    if (rideId.isEmpty || userId.isEmpty) {
      errorMessage = 'Ride ID ili User ID ne može biti prazan.';
      notifyListeners();
      return;
    }
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.joinRideRequest(
        rideId,
        userId,
        exitLocation: exitLocation,
      );
      errorMessage = null;
      _logger.d("Korisnik $userId poslao zahtjev za vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno slanje zahtjeva: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approvePassenger(
      String rideId, String passengerId, bool approve) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.approvePassenger(rideId, passengerId, approve);
      errorMessage = null;
      _logger.d("Putnik $passengerId odobren/odbijen za vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno odobravanje putnika: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePassengerExitLocation(
      String rideId, String passengerId, GeoPoint exitLocation) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.updatePassengerExitLocation(
        rideId,
        passengerId,
        exitLocation,
      );
      errorMessage = null;
      _logger.d(
          "Ažurirana izlazna točka za putnika $passengerId u vožnji $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno ažuriranje izlazne točke putnika: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rateUser(String ratedUserId, String fromUserId, double rating,
      {String? comment}) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.rateUser(ratedUserId, fromUserId, rating,
          comment: comment);
      errorMessage = null;
      _logger
          .d("Korisnik $ratedUserId ocijenjen od $fromUserId, ocjena: $rating");
    } catch (e) {
      errorMessage = 'Neuspješno ocjenjivanje korisnika: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRide(String rideId) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.updateRideStatus(rideId, RideStatus.active);
      errorMessage = null;
      _logger.d("Vožnja $rideId je sada aktivna.");
    } catch (e) {
      errorMessage = 'Neuspješno pokretanje vožnje: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finishRide(String rideId) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.updateRideStatus(rideId, RideStatus.completed);
      errorMessage = null;
      _logger.d("Vožnja $rideId je završena.");
    } catch (e) {
      errorMessage = 'Neuspješno završavanje vožnje: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> giftCandiesToDriver(
    String rideId,
    String driverId,
    String fromUserId,
    int candies,
    String? message,
  ) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.giftCandiesToDriver(
        rideId,
        driverId,
        fromUserId,
        candies,
        message,
      );
      errorMessage = null;
      _logger
          .d("Poklonjeno $candies bonbona vozaču $driverId za vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Greška prilikom darivanja bonbona: $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelRideAsDriver(String rideId) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.cancelRideAsDriver(rideId);
      errorMessage = null;
      _logger.d("Vozač je otkazao vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno otkazivanje vožnje (vozač): $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelRideAsPassenger(String rideId, String passengerId) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.cancelRideAsPassenger(rideId, passengerId);
      errorMessage = null;
      _logger.d("Putnik $passengerId je otkazao vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno otkazivanje vožnje (putnik): $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> finishRideForPassenger(
    String rideId,
    String passengerId, {
    GeoPoint? finalLocation,
  }) async {
    try {
      isLoading = true;
      notifyListeners();
      await _commuteService.finishRideForPassenger(
        rideId,
        passengerId,
        finalLocation: finalLocation,
      );
      errorMessage = null;
      _logger.d("Putnik $passengerId je završio vožnju $rideId.");
    } catch (e) {
      errorMessage = 'Neuspješno završavanje vožnje (putnik): $e';
      _logger.e(errorMessage);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _availableRidesSubject.close();
    _myRidesSubject.close();
    _historyRidesSubject.close();
    super.dispose();
  }
}
