import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/ride_view_model.dart';
import '../models/ride_model.dart';
import '../services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../commute_widgets/commute_map_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class CommuteCreateRideScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const CommuteCreateRideScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _CommuteCreateRideScreenState createState() =>
      _CommuteCreateRideScreenState();
}

class _CommuteCreateRideScreenState extends State<CommuteCreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rideId = const Uuid().v4();

  String _startAddress = '';
  String _endAddress = '';
  GeoPoint _startLocation = const GeoPoint(45.8150, 15.9819);
  GeoPoint _endLocation = const GeoPoint(45.8150, 15.9819);

  DateTime _departureTime = DateTime.now().add(const Duration(hours: 2));

  int _seatsAvailable = 3;
  final List<String> _recurringDays = [];
  List<GeoPoint> _route = [];

  Future<void> _pickLocation(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommuteMapPicker(
          title: Provider.of<LocalizationService>(context, listen: false)
                  .translate('select_location') ??
              'Odaberi lokaciju',
        ),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        final latitude = result['latitude'] as double;
        final longitude = result['longitude'] as double;
        final address = result['address'] as String? ?? '';

        if (isStart) {
          _startLocation = GeoPoint(latitude, longitude);
          _startAddress = address;
        } else {
          _endLocation = GeoPoint(latitude, longitude);
          _endAddress = address;
        }

        _route = [_startLocation, _endLocation];
      });
    }
  }

  Future<void> _setStartLocationToCurrent() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('location_services_disabled') ??
                'Lokacijske usluge nisu omogućene.',
          ),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocalizationService>(context, listen: false)
                      .translate('location_permission_denied') ??
                  'Dozvola za pristup lokaciji je odbijena.',
            ),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                    .translate('location_permission_permanently_denied') ??
                'Dozvola za pristup lokaciji je trajno odbijena.',
          ),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _startLocation = GeoPoint(position.latitude, position.longitude);
      _startAddress = Provider.of<LocalizationService>(context, listen: false)
              .translate('current_location') ??
          'Trenutna lokacija';
      _route = [_startLocation, _endLocation];
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    final rideViewModel = Provider.of<RideViewModel>(context);
    final userService = Provider.of<UserService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          localization.translate('ride') ?? 'Vožnja',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                '${localization.translate('ride_id') ?? 'Vožnja ID:'} $_rideId',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText:
                      localization.translate('start_point') ?? 'Polazište',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _setStartLocationToCurrent,
                    tooltip: localization.translate('use_current_location') ??
                        'Koristi trenutnu lokaciju',
                  ),
                ),
                readOnly: true,
                onTap: () => _pickLocation(true),
                controller: TextEditingController(text: _startAddress),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localization.translate('select_start_point') ??
                        'Odaberite lokaciju';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText:
                      localization.translate('destination') ?? 'Odredište',
                ),
                readOnly: true,
                onTap: () => _pickLocation(false),
                controller: TextEditingController(text: _endAddress),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localization.translate('select_destination') ??
                        'Odaberite odredište';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _departureTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (selectedDate != null) {
                    final selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_departureTime),
                    );
                    if (selectedTime != null) {
                      setState(() {
                        _departureTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Text(
                  DateFormat("d.M.yyyy. - HH:mm'h'").format(_departureTime),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: localization.translate('available_seats') ??
                      'Broj slobodnih mjesta',
                ),
                keyboardType: TextInputType.number,
                initialValue: _seatsAvailable.toString(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localization.translate('enter_available_seats') ??
                        'Unesite broj slobodnih mjesta';
                  }
                  return null;
                },
                onChanged: (value) {
                  _seatsAvailable = int.tryParse(value) ?? 3;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      List<String> days = [
                        localization.translate('monday') ?? 'Monday',
                        localization.translate('tuesday') ?? 'Tuesday',
                        localization.translate('wednesday') ?? 'Wednesday',
                        localization.translate('thursday') ?? 'Thursday',
                        localization.translate('friday') ?? 'Friday',
                        localization.translate('saturday') ?? 'Saturday',
                        localization.translate('sunday') ?? 'Sunday',
                      ];
                      List<bool> selected =
                          List<bool>.filled(days.length, false);
                      return AlertDialog(
                        title: Text(
                            localization.translate('choose_recurring_days') ??
                                'Odaberite ponavljajuće dane'),
                        content: StatefulBuilder(
                          builder: (context, setStateDialog) {
                            return SingleChildScrollView(
                              child: Column(
                                children: List.generate(days.length, (index) {
                                  return CheckboxListTile(
                                    title: Text(days[index]),
                                    value: selected[index],
                                    onChanged: (bool? value) {
                                      setStateDialog(() {
                                        selected[index] = value ?? false;
                                      });
                                    },
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                                localization.translate('cancel') ?? 'Otkazi'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _recurringDays.clear();
                                for (int i = 0; i < days.length; i++) {
                                  if (selected[i]) {
                                    _recurringDays.add(days[i]);
                                  }
                                }
                              });
                              Navigator.of(context).pop();
                            },
                            child: Text(
                                localization.translate('confirm') ?? 'Potvrdi'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text(
                  _recurringDays.isEmpty
                      ? localization.translate('select_recurring_days') ??
                          'Odaberi ponavljajuće dane'
                      : '${localization.translate('recurring_days') ?? 'Ponavljajući dani:'} ${_recurringDays.join(', ')}',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final currentUser = userService.currentUser;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localization.translate('user_not_logged_in') ??
                                'Korisnik nije prijavljen!',
                          ),
                        ),
                      );
                      return;
                    }

                    final newRide = Ride(
                      rideId: _rideId,
                      driverId: currentUser.uid,
                      driverName: '',
                      driverPhotoUrl: '',
                      startAddress: _startAddress,
                      startLocation: _startLocation,
                      endAddress: _endAddress,
                      endLocation: _endLocation,
                      departureTime: _departureTime,
                      seatsAvailable: _seatsAvailable,
                      passengers: [],
                      passengerRequests: [],
                      recurringDays: _recurringDays,
                      route: _route,
                      createdAt: Timestamp.now(),
                      status: RideStatus.open,
                    );

                    await rideViewModel.createRide(newRide);

                    if (rideViewModel.errorMessage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localization
                                    .translate('ride_created_successfully') ??
                                'Vožnja uspješno kreirana!',
                          ),
                        ),
                      );
                      Navigator.pop(context, newRide);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(rideViewModel.errorMessage!),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                    localization.translate('save_ride') ?? 'Spremi vožnju'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
