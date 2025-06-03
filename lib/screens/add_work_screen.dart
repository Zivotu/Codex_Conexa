// lib/screens/add_work_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class AddWorkScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const AddWorkScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  AddWorkScreenState createState() => AddWorkScreenState();
}

class AddWorkScreenState extends State<AddWorkScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _notificationController = TextEditingController();
  String? _selectedColor;
  bool _oneDayWork = false;
  bool _specialNotification = false;
  bool _notify1HourBefore = false;
  bool _notify4HoursBefore = false;
  bool _notify1DayBefore = false;

  final List<String> _colors = ['Yellow', 'Orange', 'Red', 'Black'];

  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final data = await _userService.getUserDocument(user);
      if (data != null) {
        setState(() {
          _userData = data;
          // Postavljanje vrijednosti u kontrolere
          _nameController.text = data['displayName'] ?? '';
          _floorController.text = data['floor'] ?? '';
          _apartmentController.text = data['apartmentNumber'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _detailsController.text = data['details'] ?? '';
        });
      } else {
        debugPrint('User data not found for user ${user.uid}');
      }
    } else {
      debugPrint('No authenticated user found');
    }
  }

  void _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_oneDayWork) {
          _endDate = picked;
        }
      });
    }
  }

  void _pickEndDate() async {
    final DateTime initialDate = _endDate ?? _startDate ?? DateTime.now();
    final DateTime firstDate = _startDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_startDate == null || (!_oneDayWork && _endDate == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocalizationService>(context, listen: false)
                      .translate('please_select_dates') ??
                  'Please select dates.',
            ),
          ),
        );
        return;
      }

      _formKey.currentState?.save();

      final startDateStr = _startDate!.toIso8601String();
      final endDateStr =
          _oneDayWork ? startDateStr : _endDate!.toIso8601String();
      final name = _nameController.text.trim();
      final floor = _floorController.text.trim();
      final apartment = _apartmentController.text.trim();
      final description = _descriptionController.text.trim();
      final details = _detailsController.text.trim();
      final color = _selectedColor ?? '';
      final notificationMessage = _notificationController.text.trim();
      final notifications = {
        'notify1HourBefore': _notify1HourBefore,
        'notify4HoursBefore': _notify4HoursBefore,
        'notify1DayBefore': _notify1DayBefore,
      };

      try {
        CollectionReference constructions =
            _locationService.getConstructionsCollection(
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
        );

        await constructions.add({
          'username': widget.username,
          'description': description,
          'details': details,
          'startDate': startDateStr,
          'endDate': endDateStr,
          'color': color,
          'notificationMessage': notificationMessage,
          'notifications': notifications,
          'createdAt': FieldValue.serverTimestamp(),
          // Dodavanje korisničkih podataka ako je potrebno
          'userEmail': _userData?['email'] ?? '',
          'displayName': _userData?['displayName'] ?? '',
        });

        debugPrint(
            'Work submitted: $startDateStr - $endDateStr, $name, $floor, $apartment, $description, $details, $color');
        Navigator.pop(context, true);
      } catch (error) {
        debugPrint('Error saving data: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LocalizationService>(context, listen: false)
                      .translate('error_saving_data') ??
                  'Error saving data.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('add_work') ?? 'Add Work'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _userData == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    CheckboxListTile(
                      title: Text(
                          localizationService.translate('one_day_work') ??
                              'One Day Work'),
                      value: _oneDayWork,
                      onChanged: (value) {
                        setState(() {
                          _oneDayWork = value ?? false;
                          if (_oneDayWork) {
                            _endDate = _startDate;
                          } else {
                            _endDate = null;
                          }
                        });
                      },
                    ),
                    ListTile(
                      title: Text(localizationService.translate('start_date') ??
                          'Start Date'),
                      subtitle: Text(
                        _startDate != null
                            ? DateFormat.yMd().format(_startDate!)
                            : (localizationService
                                    .translate('select_start_date') ??
                                'Select start date'),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickStartDate,
                    ),
                    ListTile(
                      title: Text(localizationService.translate('end_date') ??
                          'End Date'),
                      subtitle: Text(
                        _oneDayWork
                            ? (localizationService.translate('one_day_work') ??
                                'One Day Work')
                            : (_endDate != null
                                ? DateFormat.yMd().format(_endDate!)
                                : (localizationService
                                        .translate('select_end_date') ??
                                    'Select end date')),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _oneDayWork ? null : _pickEndDate,
                    ),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('name') ?? 'Name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizationService
                                  .translate('please_enter_name') ??
                              'Please enter your name.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _floorController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('floor') ?? 'Floor',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizationService
                                  .translate('please_enter_floor') ??
                              'Please enter your floor.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _apartmentController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('apartment') ??
                            'Apartment',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizationService
                                  .translate('please_enter_apartment') ??
                              'Please enter your apartment number.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('description') ??
                                'Description',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizationService
                                  .translate('please_enter_description') ??
                              'Please enter a description.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _detailsController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('details') ??
                            'Details',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedColor,
                      hint: Text(
                        localizationService.translate('select_color') ??
                            'Select Color',
                      ),
                      items: _colors.map((color) {
                        return DropdownMenuItem<String>(
                          value: color,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                color: _getColorForEvent({'color': color}),
                              ),
                              const SizedBox(width: 10),
                              Text(localizationService
                                      .translate(color.toLowerCase()) ??
                                  color),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedColor = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('please_select_color') ??
                              'Please select a color.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      title: Text(localizationService
                              .translate('special_notifications') ??
                          'Special Notifications'),
                      value: _specialNotification,
                      onChanged: (value) {
                        setState(() {
                          _specialNotification = value ?? false;
                        });
                      },
                    ),
                    if (_specialNotification)
                      TextFormField(
                        controller: _notificationController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: localizationService
                                  .translate('notification_message') ??
                              'Notification Message',
                          counterText: '',
                        ),
                        validator: (value) {
                          if (_specialNotification &&
                              (value == null || value.trim().isEmpty)) {
                            return localizationService
                                    .translate('please_enter_notification') ??
                                'Please enter a notification message.';
                          }
                          return null;
                        },
                      ),
                    if (_specialNotification)
                      Column(
                        children: [
                          CheckboxListTile(
                            title: Text(localizationService
                                    .translate('notify_1_hour_before') ??
                                'Notify 1 Hour Before'),
                            value: _notify1HourBefore,
                            onChanged: (value) {
                              setState(() {
                                _notify1HourBefore = value ?? false;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: Text(localizationService
                                    .translate('notify_4_hours_before') ??
                                'Notify 4 Hours Before'),
                            value: _notify4HoursBefore,
                            onChanged: (value) {
                              setState(() {
                                _notify4HoursBefore = value ?? false;
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: Text(localizationService
                                    .translate('notify_1_day_before') ??
                                'Notify 1 Day Before'),
                            value: _notify1DayBefore,
                            onChanged: (value) {
                              setState(() {
                                _notify1DayBefore = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        localizationService.translate('submit') ?? 'Submit',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Color _getColorForEvent(Map<String, dynamic> event) {
    switch (event['color']) {
      case 'Yellow':
        return Colors.yellow;
      case 'Orange':
        return Colors.orange;
      case 'Red':
        return Colors.red;
      case 'Black':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }
}
