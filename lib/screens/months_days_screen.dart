// lib/screens/months_days_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/parking_schedule_service.dart';
import '../services/user_service.dart';
import '../models/parking_slot.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parking_request.dart';
import '../services/localization_service.dart';
import 'package:provider/provider.dart'; // Dodajte ovaj import

class MonthsDaysScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String username;
  final bool locationAdmin;

  const MonthsDaysScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.username,
    required this.locationAdmin,
  });

  @override
  _MonthsDaysScreenState createState() => _MonthsDaysScreenState();
}

class _MonthsDaysScreenState extends State<MonthsDaysScreen> {
  final ParkingScheduleService _parkingScheduleService =
      ParkingScheduleService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  final List<DateTime> _months = [];
  List<ParkingSlot> _allSlots = [];
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Map<String, Map<String, dynamic>> _ownerDataCache = {};

  @override
  void initState() {
    super.initState();
    _initMonths();
    _loadSlots();
  }

  void _initMonths() {
    DateTime now = DateTime.now();
    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    for (int i = 0; i < 6; i++) {
      DateTime m = DateTime(startOfMonth.year, startOfMonth.month + i, 1);
      _months.add(m);
    }
  }

  Future<void> _loadSlots() async {
    try {
      QuerySnapshot parkingUsersSnapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('parking')
          .get();

      List<ParkingSlot> allSlots = [];
      for (var userDoc in parkingUsersSnapshot.docs) {
        QuerySnapshot slotSnapshot =
            await userDoc.reference.collection('parkingSlots').get();
        for (var slotDoc in slotSnapshot.docs) {
          var data = slotDoc.data() as Map<String, dynamic>;
          ParkingSlot slot = ParkingSlot.fromMap(data, slotDoc.id);
          allSlots.add(slot);
        }
      }

      Map<String, Map<String, dynamic>> ownerDataCache = {};
      for (var slot in allSlots) {
        if (!ownerDataCache.containsKey(slot.ownerId)) {
          Map<String, dynamic>? uData =
              await _userService.getUserDocumentById(slot.ownerId);
          ownerDataCache[slot.ownerId] = uData ?? {};
        }
      }

      setState(() {
        _allSlots = allSlots;
        _ownerDataCache = ownerDataCache;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(context, 'loadError', isError: true);
    }
  }

  String _getDayType(int weekday) {
    return (weekday >= 1 && weekday <= 5) ? 'weekday' : 'weekend';
  }

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localization.translate('community_parking_schedule') ??
              'Raspored zajedničkog parkiranja'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('community_parking_schedule') ??
            'Raspored zajedničkog parkiranja'),
      ),
      body: ListView.builder(
        itemCount: _months.length,
        itemBuilder: (context, index) {
          DateTime monthStart = _months[index];
          return _buildMonthSection(monthStart, localization);
        },
      ),
    );
  }

  Widget _buildMonthSection(
      DateTime monthStart, LocalizationService localization) {
    int year = monthStart.year;
    int month = monthStart.month;
    int daysInMonth = DateTime(year, month + 1, 0).day;

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    List<Widget> dayWidgets = [];

    for (int day = 1; day <= daysInMonth; day++) {
      DateTime date = DateTime(year, month, day);
      if (date.isBefore(today)) {
        continue;
      }

      List<ParkingSlot> availableSlots = _filterSlotsForDate(date);
      List<ParkingSlot> onVacationSlots = _filterSlotsOnVacation(date);

      if (availableSlots.isEmpty && onVacationSlots.isEmpty) {
        continue;
      }

      List<Widget> slotWidgets = [];

      // Prikaz dostupnih slotova
      if (availableSlots.isNotEmpty) {
        slotWidgets
            .add(_buildAvailableSlotsList(availableSlots, date, localization));
      }

      // Prikaz slotova na godišnjem odmoru
      if (onVacationSlots.isNotEmpty) {
        slotWidgets
            .add(_buildVacationSlotsList(onVacationSlots, date, localization));
      }

      dayWidgets.add(Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} - ${_getWeekdayName(date.weekday, localization)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...slotWidgets,
            ],
          ),
        ),
      ));
    }

    if (dayWidgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
            '${_getMonthName(monthStart.month, localization)} $year - ${localization.translate('no_upcoming_slots') ?? 'Nema nadolazećih parkirnih mjesta'}'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getMonthName(monthStart.month, localization)} $year',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...dayWidgets,
        ],
      ),
    );
  }

  // Filtriranje slotova za određeni dan
  List<ParkingSlot> _filterSlotsForDate(DateTime date) {
    List<ParkingSlot> available = [];
    for (var slot in _allSlots) {
      // Provjera godišnjeg odmora
      bool isOnVacation = false;
      if (slot.vacation != null) {
        final vac = slot.vacation!;
        if (!date.isBefore(vac.startDate) && !date.isAfter(vac.endDate)) {
          isOnVacation = true;
        }
      }

      if (isOnVacation) {
        // Ako je na godišnjem odmoru, ali također ima trajnu raspoloživost,
        // dodajemo ga kao dostupnog sa svojim vremenom
        if (slot.permanentAvailability != null &&
            slot.permanentAvailability!.isEnabled) {
          String dayType = _getDayType(date.weekday);
          if (slot.permanentAvailability!.days.contains(dayType)) {
            if (_coversInterval(slot.permanentAvailability!, 0, 24)) {
              // Cijeli dan
              available.add(slot);
            }
          }
        }
        continue; // Inače, slot je na godišnjem odmoru, ne dodajemo ga
      }

      // Provjera trajne raspoloživosti
      if (slot.permanentAvailability != null &&
          slot.permanentAvailability!.isEnabled) {
        String dayType = _getDayType(date.weekday);
        if (slot.permanentAvailability!.days.contains(dayType)) {
          available.add(slot);
        }
      }
    }
    return available;
  }

  // Filtriranje slotova na godišnjem odmoru za određeni dan
  List<ParkingSlot> _filterSlotsOnVacation(DateTime date) {
    List<ParkingSlot> onVacation = [];
    for (var slot in _allSlots) {
      if (slot.vacation != null) {
        final vac = slot.vacation!;
        if (!date.isBefore(vac.startDate) && !date.isAfter(vac.endDate)) {
          onVacation.add(slot);
        }
      }
    }
    return onVacation;
  }

  // Provjera pokrivanja intervala
  bool _coversInterval(PermanentAvailability pa, int startH, int endH) {
    TimeOfDay startPA = _parseTime(pa.startTime);
    TimeOfDay endPA = _parseTime(pa.endTime);

    int startPAmin = startPA.hour * 60 + startPA.minute;
    int endPAmin = endPA.hour * 60 + endPA.minute;
    int startInt = startH * 60;
    int endInt = endH * 60;

    return startPAmin <= startInt && endPAmin >= endInt;
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    return TimeOfDay(hour: h, minute: m);
  }

  String _getMonthName(int month, LocalizationService localization) {
    const List<String> monthKeys = [
      "january",
      "february",
      "march",
      "april",
      "may",
      "june",
      "july",
      "august",
      "september",
      "october",
      "november",
      "december"
    ];
    return localization.translate(monthKeys[month - 1]) ??
        _defaultMonthName(month);
  }

  String _defaultMonthName(int month) {
    const List<String> defaultMonths = [
      "Januar",
      "Februar",
      "Mart",
      "April",
      "Maj",
      "Juni",
      "Juli",
      "August",
      "Septembar",
      "Oktobar",
      "Novembar",
      "Decembar"
    ];
    return defaultMonths[month - 1];
  }

  String _getWeekdayName(int weekday, LocalizationService localization) {
    switch (weekday) {
      case 1:
        return localization.translate('monday') ?? 'Ponedjeljak';
      case 2:
        return localization.translate('tuesday') ?? 'Utorak';
      case 3:
        return localization.translate('wednesday') ?? 'Srijeda';
      case 4:
        return localization.translate('thursday') ?? 'Četvrtak';
      case 5:
        return localization.translate('friday') ?? 'Petak';
      case 6:
        return localization.translate('saturday') ?? 'Subota';
      case 7:
        return localization.translate('sunday') ?? 'Nedjelja';
      default:
        return '';
    }
  }

  Widget _buildAvailableSlotsList(List<ParkingSlot> slots, DateTime date,
      LocalizationService localization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            localization.translate('available_slots') ??
                'Dostupna parkirna mjesta',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...slots
            .map((slot) => _buildAvailableSlotTile(slot, date, localization)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAvailableSlotTile(
      ParkingSlot slot, DateTime date, LocalizationService localization) {
    final ownerData = _ownerDataCache[slot.ownerId] ?? {};
    String displayName = ownerData['displayName'] ??
        localization.translate('unknown') ??
        'Nepoznato';
    String profileImageUrl = ownerData['profileImageUrl'] ?? '';
    bool canRequest = slot.ownerId != currentUserId;

    String availabilityTime = '00:00 - 00:00'; // Default for "cijeli dan"
    if (slot.permanentAvailability != null &&
        slot.permanentAvailability!.isEnabled) {
      availabilityTime =
          '${slot.permanentAvailability!.startTime} - ${slot.permanentAvailability!.endTime}';
    }

    return FutureBuilder<ParkingRequest?>(
      future: _parkingScheduleService.getAssignedRequestForSlotOnDate(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
        slotId: slot.id,
        date: date,
        startTime: '00:00',
        endTime: '23:59',
      ),
      builder: (context, assignedSnap) {
        bool isTaken = assignedSnap.data != null;
        ParkingRequest? assignedRequest = assignedSnap.data;

        if (assignedSnap.connectionState == ConnectionState.waiting) {
          return ListTile(
            title: Text(localization.translate('loading') ?? 'Učitavanje...'),
          );
        }

        if (isTaken && assignedRequest != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future:
                _userService.getUserDocumentById(assignedRequest.requesterId),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return ListTile(
                  title: Text(
                      localization.translate('loading') ?? 'Učitavanje...'),
                );
              }
              Map<String, dynamic>? userData = userSnap.data;
              String uName = userData?['displayName'] ??
                  localization.translate('unknown') ??
                  'Nepoznato';
              String uImage = userData?['profileImageUrl'] ?? '';

              return Container(
                color: canRequest ? Colors.white : Colors.grey[300],
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        (uImage.isNotEmpty && uImage.startsWith('http'))
                            ? NetworkImage(uImage)
                            : const AssetImage('assets/images/default_user.png')
                                as ImageProvider,
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: '${slot.name} '),
                        TextSpan(
                          text: '($displayName)',
                          style: const TextStyle(
                            color: Colors.black54, // Izblijedjeli tekst
                          ),
                        ),
                        TextSpan(
                            text:
                                ' - ${localization.translate('taken_by') ?? 'Zauzeo'}: $uName'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          return Container(
            color: canRequest ? Colors.white : Colors.grey[300],
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (profileImageUrl.isNotEmpty &&
                        profileImageUrl.startsWith('http'))
                    ? NetworkImage(profileImageUrl)
                    : const AssetImage('assets/images/default_user.png')
                        as ImageProvider,
              ),
              title: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${slot.name} '),
                    TextSpan(
                      text: '($displayName)',
                      style: const TextStyle(
                        color: Colors.black54, // Izblijedjeli tekst
                      ),
                    ),
                    TextSpan(text: ' - $availabilityTime'),
                  ],
                ),
              ),
              trailing: canRequest
                  ? ElevatedButton(
                      onPressed: () {
                        _showRequestDialog(slot, date, localization);
                      },
                      child: Text(
                          localization.translate('reserve') ?? 'Rezerviraj'),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
      },
    );
  }

  Widget _buildVacationSlotsList(List<ParkingSlot> slots, DateTime date,
      LocalizationService localization) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localization.translate('on_vacation') ?? 'Na godišnjem odmoru',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 4),
        ...slots
            .map((slot) => _buildVacationSlotTile(slot, date, localization)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildVacationSlotTile(
      ParkingSlot slot, DateTime date, LocalizationService localization) {
    final ownerData = _ownerDataCache[slot.ownerId] ?? {};
    String displayName = ownerData['displayName'] ??
        localization.translate('unknown') ??
        'Nepoznato';
    String profileImageUrl = ownerData['profileImageUrl'] ?? '';
    bool canRequest = slot.ownerId != currentUserId;

    String vacationTime = 'Cijeli dan'; // Alternativno: '00:00 - 00:00'

    return FutureBuilder<ParkingRequest?>(
      future: _parkingScheduleService.getAssignedRequestForSlotOnDate(
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
        slotId: slot.id,
        date: date,
        startTime: '00:00',
        endTime: '23:59',
      ),
      builder: (context, assignedSnap) {
        bool isTaken = assignedSnap.data != null;
        ParkingRequest? assignedRequest = assignedSnap.data;

        if (assignedSnap.connectionState == ConnectionState.waiting) {
          return ListTile(
            title: Text(localization.translate('loading') ?? 'Učitavanje...'),
          );
        }

        if (isTaken && assignedRequest != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future:
                _userService.getUserDocumentById(assignedRequest.requesterId),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return ListTile(
                  title: Text(
                      localization.translate('loading') ?? 'Učitavanje...'),
                );
              }
              Map<String, dynamic>? userData = userSnap.data;
              String uName = userData?['displayName'] ??
                  localization.translate('unknown') ??
                  'Nepoznato';
              String uImage = userData?['profileImageUrl'] ?? '';

              return Container(
                color: canRequest ? Colors.white : Colors.grey[300],
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        (uImage.isNotEmpty && uImage.startsWith('http'))
                            ? NetworkImage(uImage)
                            : const AssetImage('assets/images/default_user.png')
                                as ImageProvider,
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(text: '${slot.name} '),
                        TextSpan(
                          text: '($displayName)',
                          style: const TextStyle(
                            color: Colors.black54, // Izblijedjeli tekst
                          ),
                        ),
                        TextSpan(
                            text:
                                ' - ${localization.translate('taken_by') ?? 'Zauzeo'}: $uName'),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          return Container(
            color: canRequest ? Colors.white : Colors.grey[300],
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (profileImageUrl.isNotEmpty &&
                        profileImageUrl.startsWith('http'))
                    ? NetworkImage(profileImageUrl)
                    : const AssetImage('assets/images/default_user.png')
                        as ImageProvider,
              ),
              title: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${slot.name} '),
                    TextSpan(
                      text: '($displayName)',
                      style: const TextStyle(
                        color: Colors.black54, // Izblijedjeli tekst
                      ),
                    ),
                    TextSpan(text: ' - $vacationTime'),
                  ],
                ),
              ),
              trailing: canRequest
                  ? ElevatedButton(
                      onPressed: () {
                        _showRequestDialog(slot, date, localization);
                      },
                      child: Text(
                          localization.translate('reserve') ?? 'Rezerviraj'),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
      },
    );
  }

  void _showRequestDialog(
      ParkingSlot slot, DateTime date, LocalizationService localization) {
    String message = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              '${localization.translate('request_use') ?? 'Zahtjev za korištenje'}: ${slot.name}'),
          content: TextFormField(
            decoration: InputDecoration(
              labelText: localization.translate('message_optional') ??
                  'Poruka (opcionalno)',
            ),
            onChanged: (value) {
              message = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localization.translate('cancel') ?? 'Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _sendParkingRequest(slot, date, message, localization);
              },
              child: Text(
                  localization.translate('send_request') ?? 'Pošalji zahtjev'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendParkingRequest(ParkingSlot slot, DateTime date,
      String message, LocalizationService localization) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      final requestId = await _parkingScheduleService.createParkingRequest(
        userId: userId,
        countryId: widget.countryId,
        cityId: widget.cityId,
        locationId: widget.locationId,
        numberOfSpots: 1,
        startDate: date,
        startTime: '00:00',
        endDate: date,
        endTime: '23:59',
        message: message.trim().isNotEmpty ? message.trim() : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                localization.translate('request_sent_wait_approval') ??
                    'Zahtjev poslan, čekajte odobrenje.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localization.translate('request_failed') ??
                'Slanje zahtjeva nije uspjelo.')),
      );
    }
  }

  void _showSnackBar(BuildContext context, String key, {bool isError = false}) {
    final localization =
        Provider.of<LocalizationService>(context, listen: false);
    String message;
    switch (key) {
      case 'loadError':
        message = localization.translate('loadError') ??
            'Greška pri učitavanju parkirnih mjesta.';
        break;
      case 'request_sent_wait_approval':
        message = localization.translate('request_sent_wait_approval') ??
            'Zahtjev poslan, čekajte odobrenje.';
        break;
      case 'request_failed':
        message = localization.translate('request_failed') ??
            'Slanje zahtjeva nije uspjelo.';
        break;
      default:
        message = key;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
