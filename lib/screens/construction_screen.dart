// lib/screens/construction_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'infos/info_construction.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class ConstructionScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const ConstructionScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  ConstructionScreenState createState() => ConstructionScreenState();
}

class ConstructionScreenState extends State<ConstructionScreen> {
  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _works = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    // Prikaz onboarding ekrana nakon inicijalnog renderiranja
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingScreen(context);
    });
    _fetchCurrentUsername();
    readData();
  }

  Future<void> _fetchCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _userService.getUserDocument(user);
      if (data != null && data['username'] != null) {
        setState(() {
          _currentUsername = data['username'];
        });
      }
    }
  }

  Future<void> _showOnboardingScreen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool shouldShow = prefs.getBool('show_construction_boarding') ?? true;
    debugPrint('Should show onboarding: $shouldShow');

    if (shouldShow) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const InfoConstructionScreen(),
        ),
      );
    }
  }

  Future<void> readData() async {
    try {
      CollectionReference constructionCollection =
          _locationService.getConstructionsCollection(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );

      QuerySnapshot querySnapshot = await constructionCollection.get();

      List<Map<String, dynamic>> works = [];
      Map<DateTime, List<Map<String, dynamic>>> events = {};
      DateTime today = DateTime.now();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> work = doc.data() as Map<String, dynamic>;
        DateTime endDate = DateTime.parse(work['endDate']);

        // Filtriranje radova čiji je endDate prije danas
        if (endDate.isBefore(DateTime(today.year, today.month, today.day))) {
          continue;
        }

        work['key'] = doc.id;
        works.add(work);
        DateTime startDate = DateTime.parse(work['startDate']);
        for (DateTime date = startDate;
            date.isBefore(endDate.add(const Duration(days: 1)));
            date = date.add(const Duration(days: 1))) {
          if (!events.containsKey(date)) {
            events[date] = [];
          }
          events[date]!.add(work);
        }
      }

      setState(() {
        _works = works;
        _events = events;
      });
    } catch (error) {
      debugPrint(
          '${Provider.of<LocalizationService>(context, listen: false).translate("errorReadingData") ?? "Error reading data:"} $error');
    }
  }

  void _deleteWork(String key) async {
    try {
      CollectionReference constructionCollection =
          _locationService.getConstructionsCollection(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
      );

      await constructionCollection.doc(key).delete().then((_) {
        setState(() {
          _works.removeWhere((work) => work['key'] == key);
          _events = {};
          for (var work in _works) {
            DateTime startDate = DateTime.parse(work['startDate']);
            DateTime endDate = DateTime.parse(work['endDate']);
            for (DateTime date = startDate;
                date.isBefore(endDate.add(const Duration(days: 1)));
                date = date.add(const Duration(days: 1))) {
              if (!_events.containsKey(date)) {
                _events[date] = [];
              }
              _events[date]!.add(work);
            }
          }
        });
        debugPrint(
            '${Provider.of<LocalizationService>(context, listen: false).translate("workDeleted") ?? "Work deleted:"} $key');
      }).catchError((error) {
        debugPrint(
            '${Provider.of<LocalizationService>(context, listen: false).translate("errorDeletingData") ?? "Error deleting data:"} $error');
      });
    } catch (error) {
      debugPrint(
          '${Provider.of<LocalizationService>(context, listen: false).translate("errorDeletingData") ?? "Error deleting data:"} $error');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
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

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${localizationService.translate('construction') ?? 'Construction'} - ${widget.locationId}',
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 1, 1),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.map((event) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color:
                              _getColorForEvent(event as Map<String, dynamic>),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  );
                }
                return null;
              },
              todayBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    date.day.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
              defaultBuilder: (context, date, _) {
                for (var work in _works) {
                  DateTime startDate = DateTime.parse(work['startDate']);
                  DateTime endDate = DateTime.parse(work['endDate']);
                  if (date.isAfter(
                          startDate.subtract(const Duration(days: 1))) &&
                      date.isBefore(endDate.add(const Duration(days: 1)))) {
                    return Container(
                      margin: const EdgeInsets.all(1.5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _getColorForEvent(work).withOpacity(0.5),
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _works.length,
              itemBuilder: (context, index) {
                final work = _works[index];
                final key = work['key'];
                final startDate =
                    DateFormat.yMd().format(DateTime.parse(work['startDate']));
                final endDate =
                    DateFormat.yMd().format(DateTime.parse(work['endDate']));
                final isCreator = _currentUsername == work['username'];

                return Card(
                  child: ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work['description'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                            decorationColor: _getColorForEvent(work),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          work['details'] ?? '',
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          startDate == endDate
                              ? startDate
                              : '$startDate - $endDate',
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 2.0),
                              color: _getColorForEvent(work),
                              child: Text(
                                work['name'] ??
                                    localizationService.translate('no_title') ??
                                    'No Title',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isCreator
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteWork(key),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result =
              await Navigator.pushNamed(context, '/addWork', arguments: {
            'username': widget.username,
            'countryId': widget.countryId,
            'cityId': widget.cityId,
            'locationId': widget.locationId,
          });

          if (result == true) {
            await readData();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
