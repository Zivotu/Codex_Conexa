// lib/screens/create_snow_cleaning_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/schedule_service.dart';
import '../services/user_service.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class CreateSnowCleaningScheduleScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const CreateSnowCleaningScheduleScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _CreateSnowCleaningScheduleScreenState createState() =>
      _CreateSnowCleaningScheduleScreenState();
}

class _CreateSnowCleaningScheduleScreenState
    extends State<CreateSnowCleaningScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final UserService _userService = UserService();
  final Logger _logger = Logger();

  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _selectedUserIds = [];
  List<String> _allUserIds = [];
  bool _isLoading = true;
  bool _isLocationAdmin = false;
  Map<String, dynamic>? _schedule;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkIfAdmin();
    await _loadUsers();
    await _loadSchedule();
  }

  Future<void> _checkIfAdmin() async {
    // Provjera da li je locationId prazan
    if (widget.locationId.isEmpty) {
      _logger.e('Location ID je prazan!');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _logger.i('Provjeravam admin status za korisnika: ${currentUser.uid}');
      _logger.i('Lokacija: ${widget.locationId}');
      try {
        bool isAdmin = await _userService.getLocationAdminStatus(
            currentUser.uid, widget.locationId);
        if (mounted) {
          setState(() {
            _isLocationAdmin = isAdmin;
          });
        }
        _logger.i(
            'Korisnik ${currentUser.uid} admin za lokaciju ${widget.locationId}: $_isLocationAdmin');
      } catch (e) {
        _logger.e('Greška pri provjeri admin statusa: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _isLocationAdmin = false;
        });
      }
      _logger.w('Korisnik nije prijavljen.');
    }
  }

  Future<void> _loadUsers() async {
    // Provjera da li je locationId prazan
    if (widget.locationId.isEmpty) {
      _logger.e('Location ID je prazan! Ne mogu učitati korisnike.');
      if (mounted) {
        setState(() {
          _allUserIds = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('users')
          .get();

      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();

      if (mounted) {
        setState(() {
          _allUserIds = userIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allUserIds = [];
          _isLoading = false;
        });
      }
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_loading_users')}: $e');
      _logger.e('Greška pri učitavanju korisnika: $e');
    }
  }

  Future<void> _loadSchedule() async {
    // Provjera da li je locationId prazan
    if (widget.locationId.isEmpty) {
      _logger.e('Location ID je prazan! Ne mogu dohvatiti raspored.');
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final schedule = await _scheduleService.getSchedule(
        widget.countryId,
        widget.cityId,
        widget.locationId,
      );
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
      }
      _logger.i('Raspored dohvaćen za lokaciju ${widget.locationId}.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _schedule = null;
          _isLoading = false;
        });
      }
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_fetch_schedule')}: $e');
      _logger.e('Greška pri dohvaćanju rasporeda: $e');
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      if (mounted) {
        setState(() {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      _showErrorDialog(
          LocalizationService.instance.translate('select_start_date_first'));
      return;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      if (mounted) {
        setState(() {
          _endDate = picked;
        });
      }
    }
  }

  Future<void> _createSchedule() async {
    // Provjera da li je locationId prazan
    if (widget.locationId.isEmpty) {
      _logger.e('Location ID je prazan! Ne mogu kreirati raspored.');
      _showErrorDialog(
          LocalizationService.instance.translate('location_id_missing'));
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showErrorDialog(
          LocalizationService.instance.translate('select_start_end_dates'));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      _showErrorDialog(
          LocalizationService.instance.translate('select_at_least_one_user'));
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorDialog(
            LocalizationService.instance.translate('user_not_signed_in'));
        return;
      }
      await _scheduleService.createSchedule(
        widget.countryId,
        widget.cityId,
        widget.locationId,
        _startDate!,
        _endDate!,
        _selectedUserIds,
        currentUser.uid,
      );
      _logger.i('Raspored kreiran za lokaciju ${widget.locationId}.');
      await _showLoadingDialog();
      _navigateToSnowCleaningScreen();
    } catch (e) {
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_creating_schedule')}: $e');
      _logger.e('Greška pri kreiranju rasporeda: $e');
    }
  }

  Future<void> _deleteSchedule() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              LocalizationService.instance.translate('delete_confirmation')),
          content: Text(LocalizationService.instance
              .translate('delete_schedule_confirmation')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(backgroundColor: Colors.grey),
              child: Text(LocalizationService.instance.translate('cancel'),
                  style: const TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(LocalizationService.instance.translate('delete'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm) {
      try {
        await _scheduleService.deleteSchedule(
            widget.countryId, widget.cityId, widget.locationId);
        _logger.i('Raspored za lokaciju ${widget.locationId} obrisan.');
        await _showLoadingDialog();
        _navigateToSnowCleaningScreen();
      } catch (e) {
        _showErrorDialog(
            '${LocalizationService.instance.translate('error_deleting_schedule')}: $e');
        _logger.e('Greška pri brisanju rasporeda: $e');
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) {
      _logger
          .e('Widget je unmounted, ne mogu prikazati error dialog: $message');
      return;
    }
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LocalizationService.instance.translate('error')),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                if (mounted) Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(backgroundColor: Colors.grey),
              child: Text(LocalizationService.instance.translate('ok'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoadingDialog() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.snowflake,
                size: 40,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LocalizationService.instance
                          .translate('preparing_schedule'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop();
  }

  void _navigateToSnowCleaningScreen() {
    Navigator.of(context).pushReplacementNamed(
      '/snow_cleaning',
      arguments: {
        'countryId': widget.countryId,
        'cityId': widget.cityId,
        'locationId': widget.locationId,
        'username': FirebaseAuth.instance.currentUser?.displayName ?? '',
      },
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allUserIds.isEmpty) {
      return Center(
          child: Text(
              LocalizationService.instance.translate('no_users_for_schedule')));
    }
    return ListView.builder(
      itemCount: _allUserIds.length,
      itemBuilder: (context, index) {
        final userId = _allUserIds[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _userService.getUserDocumentById(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                title: Text(
                    LocalizationService.instance.translate('loading_user')),
                leading: const CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ListTile(
                title: Text(
                    LocalizationService.instance.translate('unknown_user')),
              );
            }
            final userData = snapshot.data!;
            String displayName = userData['displayName'] ??
                LocalizationService.instance.translate('unknown');
            String lastName = userData['lastName'] ??
                LocalizationService.instance.translate('unknown');
            return CheckboxListTile(
              title: Text('$displayName $lastName'),
              value: _selectedUserIds.contains(userId),
              onChanged: (bool? value) {
                if (mounted) {
                  setState(() {
                    if (value == true) {
                      _selectedUserIds.add(userId);
                    } else {
                      _selectedUserIds.remove(userId);
                    }
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCreateScheduleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_startDate != null || _endDate != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _startDate != null
                      ? '${LocalizationService.instance.translate('start_date')}: ${_formatDate(_startDate!)}'
                      : '${LocalizationService.instance.translate('start_date')}: ${LocalizationService.instance.translate('not_selected')}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _endDate != null
                      ? '${LocalizationService.instance.translate('end_date')}: ${_formatDate(_endDate!)}'
                      : '${LocalizationService.instance.translate('end_date')}: ${LocalizationService.instance.translate('not_selected')}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectStartDate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    LocalizationService.instance.translate('select_start_date'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectEndDate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    LocalizationService.instance.translate('select_end_date'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            LocalizationService.instance.translate('select_users_for_schedule'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildUserList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_schedule == null) {
      return Center(
          child: Text(
              LocalizationService.instance.translate('no_schedule_created')));
    }
    final assignments =
        _schedule!['assignments'] as Map<String, dynamic>? ?? {};
    List<String> dates = assignments.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${LocalizationService.instance.translate('schedule_period')}: ${_formatDate(_schedule!['startDate'])} - ${_formatDate(_schedule!['endDate'])}',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              String date = dates[index];
              String userId = assignments[date];
              DateTime dateTime = DateTime.parse(date);
              String formattedDate =
                  '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.';
              String weekday = _getWeekdayName(dateTime.weekday);
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$formattedDate - $weekday',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_isLocationAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {},
                              tooltip: LocalizationService.instance
                                  .translate('change_assignment'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _userService.getUserDocumentById(userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Text(LocalizationService.instance
                                .translate('error_loading_user'));
                          }
                          final userData = snapshot.data!;
                          String displayName = userData['displayName'] ??
                              LocalizationService.instance.translate('unknown');
                          String lastName = userData['lastName'] ??
                              LocalizationService.instance.translate('unknown');
                          String? profileImageUrl = userData['profileImageUrl'];
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: (profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty)
                                    ? NetworkImage(profileImageUrl)
                                    : const AssetImage(
                                            'assets/images/default_avatar.png')
                                        as ImageProvider,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${displayName[0].toUpperCase()}. $lastName',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              if (_isLocationAdmin)
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                  child: Text(
                                    LocalizationService.instance
                                        .translate('change'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _navigateToHome,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                LocalizationService.instance.translate('back_to_home'),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } else if (timestamp is DateTime) {
      return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year}';
    }
    return LocalizationService.instance.translate('unknown');
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return LocalizationService.instance.translate('monday');
      case 2:
        return LocalizationService.instance.translate('tuesday');
      case 3:
        return LocalizationService.instance.translate('wednesday');
      case 4:
        return LocalizationService.instance.translate('thursday');
      case 5:
        return LocalizationService.instance.translate('friday');
      case 6:
        return LocalizationService.instance.translate('saturday');
      case 7:
        return LocalizationService.instance.translate('sunday');
      default:
        return '';
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            LocalizationService.instance.translate('snow_cleaning_schedule')),
        actions: [
          if (_isLocationAdmin && _schedule != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSchedule,
              tooltip:
                  LocalizationService.instance.translate('delete_schedule'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _schedule == null
                  ? Column(
                      children: [
                        Expanded(child: _buildCreateScheduleForm()),
                      ],
                    )
                  : _buildScheduleList(),
        ),
      ),
      bottomNavigationBar: _schedule == null
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _createSchedule,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  LocalizationService.instance.translate('create_schedule'),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            )
          : null,
    );
  }
}
