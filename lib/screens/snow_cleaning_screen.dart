// lib/screens/snow_cleaning_screen.dart

import 'dart:math'; // Dodano za randomizaciju
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/schedule_service.dart';
import '../services/user_service.dart';
import 'create_snow_cleaning_schedule_screen.dart';
import 'package:logger/logger.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class SnowCleaningScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;

  const SnowCleaningScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
  });

  @override
  _SnowCleaningScreenState createState() => _SnowCleaningScreenState();
}

class _SnowCleaningScreenState extends State<SnowCleaningScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final UserService _userService = UserService();
  final Logger _logger = Logger();

  Map<String, dynamic>? _schedule;
  Map<String, dynamic>? _removalRequests;
  bool _isLoading = true;
  bool _isLocationAdmin = false;
  bool _filterCurrentUser = false;

  final Set<String> _markedForRemovalDates = {};

  // Lista ključeva za smiješne poruke i zanimljivosti
  final List<String> _jokeKeys = [
    'joke1',
    'joke2',
    'joke3',
    'joke4',
    'joke5',
    'joke6',
    'joke7',
    'joke8',
    'joke9',
    'joke10',
  ];

  final List<String> _triviaKeys = [
    'trivia1',
    'trivia2',
    'trivia3',
    'trivia4',
    'trivia5',
    'trivia6',
    'trivia7',
    'trivia8',
    'trivia9',
    'trivia10',
  ];

  String _selectedJoke = '';
  String _selectedTrivia = '';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
    _selectRandomJokeAndTrivia();
  }

  Future<void> _initializeScreen() async {
    await _checkIfAdmin();
    await _loadSchedule();
  }

  Future<void> _checkIfAdmin() async {
    // Provjera da li locationId nije prazan
    if (widget.locationId.isEmpty) {
      _logger.e('Location ID je prazan!');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_locations')
            .doc(currentUser.uid)
            .collection('locations')
            .doc(widget.locationId)
            .get();

        if (doc.exists) {
          if (mounted) {
            setState(() {
              _isLocationAdmin = doc.data()?['locationAdmin'] ?? false;
            });
          }
          _logger.i(
              'Korisnik ${currentUser.uid} admin za lokaciju ${widget.locationId}: $_isLocationAdmin');
        } else {
          if (mounted) {
            setState(() {
              _isLocationAdmin = false;
            });
          }
          _logger.w(
              'Dokument za korisnika ${currentUser.uid} za lokaciju ${widget.locationId} ne postoji.');
        }
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

  Future<void> _loadSchedule() async {
    // Provjera da li locationId nije prazan
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
      final removalRequests = await _scheduleService.getRemovalRequests(
        widget.countryId,
        widget.cityId,
        widget.locationId,
      );

      // Ako postoji zapis, provjeravamo datum završetka rasporeda.
      if (schedule != null && schedule['endDate'] != null) {
        final Timestamp endTimestamp = schedule['endDate'];
        final DateTime endDate = endTimestamp.toDate();
        if (endDate.isBefore(DateTime.now())) {
          // Ako je raspored istekao, tretiramo ga kao da ne postoji
          if (mounted) {
            setState(() {
              _schedule = null;
              _removalRequests = removalRequests;
              _isLoading = false;
            });
          }
          _logger
              .i('Raspored je istekao, omogućeno kreiranje novog rasporeda.');
          return;
        }
      }

      if (mounted) {
        setState(() {
          _schedule = schedule;
          _removalRequests = removalRequests;
          _isLoading = false;
        });
      }
      _logger.i(
          'Raspored i removal requests dohvaćeni za lokaciju ${widget.locationId}.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _schedule = null;
          _removalRequests = null;
          _isLoading = false;
        });
      }
      _selectRandomJokeAndTrivia(); // Odaberi novu foru i zanimljivost
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_fetch_schedule')}: $e');
      _logger.e('Greška pri dohvaćanju rasporeda: $e');
    }
  }

  void _selectRandomJokeAndTrivia() {
    final random = Random();
    if (mounted) {
      setState(() {
        _selectedJoke = LocalizationService.instance
            .translate(_jokeKeys[random.nextInt(_jokeKeys.length)]);
        _selectedTrivia = LocalizationService.instance
            .translate(_triviaKeys[random.nextInt(_triviaKeys.length)]);
      });
    }
  }

  Future<void> _changeAssignment(String date) async {
    try {
      // Dohvati stari userId
      final oldUserId = _schedule?['assignments'][date];
      String oldUserName =
          LocalizationService.instance.translate('unknown_user');
      if (oldUserId != null) {
        final oldUserDoc = await _userService.getUserDocumentById(oldUserId);
        if (oldUserDoc != null) {
          String displayName = oldUserDoc['displayName'] ??
              LocalizationService.instance.translate('unknown');
          String lastName = oldUserDoc['lastName'] ?? '';
          oldUserName =
              '$displayName ${lastName.isNotEmpty ? lastName : ''}'.trim();
        }
      }

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('users')
          .get();

      final users = usersSnapshot.docs.map((doc) => doc.id).toList();

      if (users.isEmpty) {
        _showErrorDialog(
            LocalizationService.instance.translate('error_no_available_users'));
        return;
      }

      showDialog(
        context: context,
        builder: (context) {
          String? selectedUserId;
          List<Map<String, String>> userOptions = [];

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(
                    '${LocalizationService.instance.translate('change_assignment_title')} $date'),
                content: SizedBox(
                  height: 300, // Fiksirana visina za sadržaj dijaloga
                  width: double.maxFinite,
                  child: FutureBuilder<List<Map<String, String>>>(
                    future: Future.wait(users.map((userId) async {
                      final userDoc =
                          await _userService.getUserDocumentById(userId);
                      if (userDoc != null) {
                        String displayName = userDoc['displayName'] ??
                            LocalizationService.instance.translate('unknown');
                        String lastName = userDoc['lastName'] ?? '';
                        return {
                          'userId': userId,
                          'name':
                              '$displayName ${lastName.isNotEmpty ? lastName : ''}'
                                  .trim()
                        };
                      } else {
                        return {
                          'userId': userId,
                          'name':
                              LocalizationService.instance.translate('unknown')
                        };
                      }
                    })),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Text(LocalizationService.instance
                            .translate('error_loading_users'));
                      }

                      userOptions = snapshot.data!;

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: userOptions.length,
                        itemBuilder: (context, index) {
                          final user = userOptions[index];
                          return RadioListTile<String>(
                            value: user['userId']!,
                            groupValue: selectedUserId,
                            onChanged: (value) {
                              setStateDialog(() {
                                selectedUserId = value;
                              });
                            },
                            title: Text(user['name']!),
                          );
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(backgroundColor: Colors.grey),
                    child: Text(
                        LocalizationService.instance.translate('cancel'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (selectedUserId != null) {
                        try {
                          await _scheduleService.updateAssignment(
                              widget.countryId,
                              widget.cityId,
                              widget.locationId,
                              date,
                              selectedUserId!);

                          // Briše postojeći zahtjev za uklanjanje za ovaj datum
                          await _scheduleService.deleteRemovalRequest(
                              widget.countryId,
                              widget.cityId,
                              widget.locationId,
                              date);

                          String newUserName =
                              LocalizationService.instance.translate('unknown');
                          final found = userOptions
                              .firstWhere((u) => u['userId'] == selectedUserId);
                          newUserName = found['name'] ??
                              LocalizationService.instance.translate('unknown');

                          Navigator.of(context).pop();
                          _showInfoDialog(LocalizationService.instance
                              .translate('assignment_changed_success')
                              .replaceFirst('{oldUser}', oldUserName)
                              .replaceFirst('{newUser}', newUserName));
                          await _loadSchedule();
                          _logger.i(
                              'Dodjela za dan $date promijenjena sa $oldUserName na $newUserName.');
                        } catch (e) {
                          _showErrorDialog(
                              '${LocalizationService.instance.translate('error_changing_assignment')}: $e');
                          _logger.e('Greška pri promjeni dodjele: $e');
                        }
                      } else {
                        _showErrorDialog(LocalizationService.instance
                            .translate('error_select_user'));
                      }
                    },
                    style: TextButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    child: Text(
                        LocalizationService.instance.translate('change'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_fetch_users')}: $e');
      _logger.e('Greška pri dohvaćanju korisnika za promjenu dodjele: $e');
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
        _showInfoDialog(
            LocalizationService.instance.translate('schedule_deleted'));
        await _loadSchedule();
        _logger.i('Raspored za lokaciju ${widget.locationId} obrisan.');
      } catch (e) {
        _showErrorDialog(
            '${LocalizationService.instance.translate('error_deleting_schedule')}: $e');
        _logger.e('Greška pri brisanju rasporeda: $e');
      }
    }
  }

  Future<void> _requestRemoval(String date, String userId) async {
    try {
      await _scheduleService.requestRemoval(
          widget.countryId, widget.cityId, widget.locationId, date, userId);
      _markedForRemovalDates.add(date);
      if (mounted) setState(() {});
      _showInfoDialog(
          LocalizationService.instance.translate('removal_request_success'));
      _logger.i(
          'Zahtjev za uklanjanje zabilježen za datum $date od korisnika $userId.');
    } catch (e) {
      _showErrorDialog(
          '${LocalizationService.instance.translate('error_recording_removal')}: $e');
      _logger.e('Greška pri bilježenju uklanjanja: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) {
      _logger
          .e('Widget je unmounted, ne mogu prikazati error dialog: $message');
      return;
    }
    showDialog(
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

  void _showInfoDialog(String message) {
    if (!mounted) {
      _logger.e('Widget je unmounted, ne mogu prikazati info dialog: $message');
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(LocalizationService.instance.translate('info')),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                if (mounted) Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: Text(LocalizationService.instance.translate('ok'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    return LocalizationService.instance.translate('unknown_date');
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

  // Pomoćna funkcija za provjeru je li raspored istekao
  bool _isScheduleExpired(Map<String, dynamic> schedule) {
    if (schedule['endDate'] != null) {
      final DateTime endDate = (schedule['endDate'] as Timestamp).toDate();
      return endDate.isBefore(DateTime.now());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.instance.translate('snow_cleaning')),
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
      body: SingleChildScrollView(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: (_schedule != null)
                    ? _buildContent(currentUser)
                    : (_isLocationAdmin
                        ? Center(
                            child: ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateSnowCleaningScheduleScreen(
                                      countryId: widget.countryId,
                                      cityId: widget.cityId,
                                      locationId: widget.locationId,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  await _loadSchedule();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                LocalizationService.instance
                                    .translate('create_schedule'),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.white),
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 50),
                              Icon(
                                Icons.ac_unit,
                                size: 100,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _selectedJoke,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _selectedTrivia,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )),
              ),
      ),
      floatingActionButton: _isLocationAdmin &&
              (_schedule == null ||
                  (_schedule != null && _isScheduleExpired(_schedule!)))
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSnowCleaningScheduleScreen(
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                      locationId: widget.locationId,
                    ),
                  ),
                );
                if (result == true) {
                  await _loadSchedule();
                }
              },
              tooltip:
                  LocalizationService.instance.translate('create_schedule'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildContent(User? currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () {
            setState(() {
              _filterCurrentUser = !_filterCurrentUser;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _filterCurrentUser
                ? LocalizationService.instance.translate('clear_filter')
                : LocalizationService.instance.translate('find_me'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        _buildScheduleListFiltered(currentUser),
      ],
    );
  }

  Widget _buildScheduleListFiltered(User? currentUser) {
    final assignments =
        _schedule?['assignments'] as Map<String, dynamic>? ?? {};
    List<String> dates = assignments.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

    // Filtrirajte samo datume od danas pa nadalje.
    DateTime today = DateTime.now();
    dates = dates.where((d) {
      DateTime date = DateTime.parse(d);
      return date.year > today.year ||
          (date.year == today.year && date.month > today.month) ||
          (date.year == today.year &&
              date.month == today.month &&
              date.day >= today.day);
    }).toList();

    if (_filterCurrentUser && currentUser != null) {
      dates = dates.where((d) => assignments[d] == currentUser.uid).toList();
    }

    if (dates.isEmpty) {
      return Center(
        child:
            Text(LocalizationService.instance.translate('no_schedule_entries')),
      );
    }

    return Column(
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
            final userId = assignments[date];
            DateTime dateTime = DateTime.parse(date);
            String formattedDate =
                '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.';
            String weekday = _getWeekdayName(dateTime.weekday);

            bool hasRemovalRequest =
                _removalRequests != null && _removalRequests!.containsKey(date);

            return FutureBuilder<Map<String, dynamic>?>(
              future: _userService.getUserDocumentById(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return ListTile(
                    title: Text(LocalizationService.instance
                        .translate('error_loading_user')),
                  );
                }

                final userData = snapshot.data!;
                String displayName = userData['displayName'] ??
                    LocalizationService.instance.translate('unknown');
                String lastName = userData['lastName'] ?? '';
                String? profileImageUrl = userData['profileImageUrl'];
                final currentUserLocal = FirebaseAuth.instance.currentUser;
                final isCurrentUser = (currentUserLocal != null &&
                    currentUserLocal.uid == userId);

                BoxDecoration cardDecoration = BoxDecoration(
                  color: isCurrentUser ? Colors.grey[200] : Colors.white,
                  border: isCurrentUser
                      ? Border.all(color: Colors.blueAccent, width: 2)
                      : Border.all(color: Colors.transparent),
                );

                bool markedForRemoval = _markedForRemovalDates.contains(date);

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: cardDecoration,
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (_isLocationAdmin)
                                  Row(
                                    children: [
                                      if (hasRemovalRequest)
                                        Tooltip(
                                          message: LocalizationService.instance
                                              .translate(
                                                  'removal_request_exists'),
                                          child: const Icon(
                                            Icons.warning,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _changeAssignment(date),
                                        tooltip: LocalizationService.instance
                                            .translate('change_assignment'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundImage: profileImageUrl != null &&
                                          profileImageUrl.isNotEmpty
                                      ? (profileImageUrl.startsWith('http')
                                          ? NetworkImage(profileImageUrl)
                                          : AssetImage(profileImageUrl)
                                              as ImageProvider)
                                      : null,
                                  child: (profileImageUrl == null ||
                                          profileImageUrl.isEmpty)
                                      ? const Icon(Icons.person,
                                          size: 30, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${displayName[0].toUpperCase()}. ${lastName.isNotEmpty ? lastName : ''}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                if (isCurrentUser)
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _requestRemoval(
                                          date, currentUserLocal.uid);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: Text(
                                      LocalizationService.instance
                                          .translate('cannot_attend'),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                if (_isLocationAdmin && !isCurrentUser)
                                  ElevatedButton(
                                    onPressed: () => _changeAssignment(date),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                    ),
                                    child: Text(
                                      LocalizationService.instance
                                          .translate('change'),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (markedForRemoval)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
