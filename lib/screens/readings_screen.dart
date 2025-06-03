// lib/screens/readings_screen.dart

// For File operations
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
// For getTemporaryDirectory
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; // For PDF sharing
import 'package:intl/intl.dart'; // For date formatting
import '../services/localization_service.dart';

class ReadingsScreen extends StatefulWidget {
  final String locationId; // Location ID to fetch location-specific data

  const ReadingsScreen({
    super.key,
    required this.locationId,
  });

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _ommController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _tariff1Controller = TextEditingController();
  final TextEditingController _tariff2Controller = TextEditingController();

  String? omm;
  String? serial;
  bool locationAdmin = false;
  List<Map<String, dynamic>> readings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroDialog();
    });
    _fetchUserData();
  }

  /// Show an introductory dialog with localized text
  Future<void> _showIntroDialog() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizationService.translate('welcome') ?? 'Welcome'),
        content: Text(
          localizationService.translate('intro_message') ??
              'Ovdje možete očitati i upisati stanje "brojila" i kronološki pratiti stanja kroz vrijeme. To je zapravo mjesto na kojem upisujete stanje i kad čovjek koji očitava stanje po stanovima dođe, nećete morati lijepiti papiriće na vrata ili slične stvari nego će predstavnik stanara moći direktno podijeliti sva stanja od svih stanara. NE brinite, nitko osim čovjeka koji očitava neće vidjeti stvarne podatke (Prijenos je šifriran i zaštićen).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizationService.translate('close') ?? 'Close'),
          ),
        ],
      ),
    );
  }

  /// Fetch user-specific data (omm, serial, locationAdmin status, and readings)
  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Fetch from /location_users/{locationId}/users/{userId}
        final userDoc = await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            omm = userDoc.data()?['omm'];
            serial = userDoc.data()?['serial'];
            locationAdmin = userDoc.data()?['locationAdmin'] ?? false;
          });
          print('OMM: $omm, Serial: $serial, Is Admin: $locationAdmin');
        }

        // Fetch user readings
        final readingsSnapshot = await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(user.uid)
            .collection('readings')
            .orderBy('timestamp', descending: true)
            .get();

        setState(() {
          readings = readingsSnapshot.docs
              .map((doc) => Map<String, dynamic>.from(doc.data()))
              .toList();
        });
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
  }

  /// Save new reading to Firestore
  Future<void> _saveReading() async {
    final user = _auth.currentUser;
    if (user != null) {
      final tariff1 = double.tryParse(_tariff1Controller.text) ?? 0.0;
      final tariff2 = double.tryParse(_tariff2Controller.text) ?? 0.0;

      final readingData = {
        'timestamp': Timestamp.now(),
        'tariff1': tariff1,
        'tariff2': tariff2,
        'userDetails': {
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'omm': omm ?? '',
          'serial': serial ?? '',
        },
      };

      try {
        await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(user.uid)
            .collection('readings')
            .add(readingData);

        setState(() {
          readings.insert(0, Map<String, dynamic>.from(readingData));
        });

        _tariff1Controller.clear();
        _tariff2Controller.clear();
      } catch (e) {
        debugPrint('Error saving reading: $e');
      }
    }
  }

  /// Save updated OMM and Serial to Firestore
  Future<void> _saveOMMAndSerial() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(user.uid)
            .update({
          'omm': _ommController.text,
          'serial': _serialController.text,
        });

        setState(() {
          omm = _ommController.text;
          serial = _serialController.text;
        });

        _ommController.clear();
        _serialController.clear();
      } catch (e) {
        debugPrint('Error saving OMM and Serial: $e');
      }
    }
  }

  /// Generate and share a PDF containing all readings
  Future<void> _shareAdminReadingsAsPdf(Map<String, dynamic> allReadings,
      LocalizationService localizationService) async {
    try {
      // Now, generate PDF
      final pdf = pw.Document();

      allReadings.forEach((month, users) {
        pdf.addPage(
          pw.MultiPage(
            build: (pw.Context context) {
              return [
                pw.Text(
                  month,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...users.entries.map((userEntry) {
                  final lastName = userEntry.key;
                  final userData = userEntry.value;
                  final omm = userData['omm'];
                  final serial = userData['serial'];
                  final readings = userData['readings'];

                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Korisnik: $lastName',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('OMM: $omm'),
                      pw.Text('Serijski broj: $serial'),
                      pw.SizedBox(height: 5),
                      // Ensure data is List<List<String>>
                      pw.Table.fromTextArray(
                        headers: ['Datum i vrijeme', 'Tarifa 1', 'Tarifa 2'],
                        data: readings
                            .map((reading) {
                              String formattedDate =
                                  DateFormat('dd. MMMM yyyy., HH:mm\'h\'', 'hr')
                                      .format(reading['timestamp']);
                              String tariff1 = reading['tariff1'].toString();
                              String tariff2 = reading['tariff2'].toString();
                              return [
                                formattedDate,
                                tariff1,
                                tariff2,
                              ];
                            })
                            .toList()
                            .cast<List<String>>(),
                        border: pw.TableBorder.all(),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                        ),
                        cellAlignment: pw.Alignment.centerLeft,
                        headerDecoration: pw.BoxDecoration(
                          color: PdfColors.grey300,
                        ),
                        cellHeight: 20,
                        columnWidths: {
                          0: pw.FlexColumnWidth(3),
                          1: pw.FlexColumnWidth(2),
                          2: pw.FlexColumnWidth(2),
                        },
                      ),
                      pw.SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ];
            },
          ),
        );
      });

      // Share the PDF
      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename:
              'readings_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      // localizationService is passed as a parameter
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('share_error') ??
                'Greška prilikom dijeljenja očitanja',
          ),
        ),
      );
    }
  }

  /// Show admin readings and share as PDF
  Future<void> _showAdminReadings() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    try {
      // Fetch all users from location_users/{locationId}/users
      final usersSnapshot = await _firestore
          .collection('location_users')
          .doc(widget.locationId)
          .collection('users')
          .get();

      Map<String, dynamic> allReadings = {};

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = Map<String, dynamic>.from(userDoc.data());

        // Get lastName from /users/{userId}
        final userInfoDoc =
            await _firestore.collection('users').doc(userId).get();

        String lastName = 'Unknown';
        if (userInfoDoc.exists) {
          final userInfo = Map<String, dynamic>.from(userInfoDoc.data()!);
          lastName = userInfo['lastName'] ?? 'Unknown';
        }

        String omm = userData['omm'] ?? 'N/A';
        String serial = userData['serial'] ?? 'N/A';

        // Fetch readings for this user
        final readingsSnapshot = await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(userId)
            .collection('readings')
            .orderBy('timestamp', descending: true)
            .get();

        for (var reading in readingsSnapshot.docs) {
          final readingData = Map<String, dynamic>.from(reading.data());

          DateTime timestamp = (readingData['timestamp'] as Timestamp).toDate();
          String month = DateFormat('MMMM yyyy', 'hr').format(timestamp);

          if (!allReadings.containsKey(month)) {
            allReadings[month] = {};
          }

          if (!allReadings[month].containsKey(lastName)) {
            allReadings[month][lastName] = {
              'omm': omm,
              'serial': serial,
              'readings': [],
            };
          }

          allReadings[month][lastName]['readings'].add({
            'timestamp': timestamp,
            'tariff1': readingData['tariff1'] ?? 0.0,
            'tariff2': readingData['tariff2'] ?? 0.0,
          });
        }
      }

      // Now, generate and share the PDF
      await _shareAdminReadingsAsPdf(allReadings, localizationService);
    } catch (e) {
      debugPrint('Error fetching admin readings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizationService.translate('share_error') ??
                'Greška prilikom dohvaćanja očitanja za administratore',
          ),
        ),
      );
    }
  }

  /// Main build method for the widget (StatefulWidget)
  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('readings') ?? 'Očitanja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _ommController,
                        decoration: InputDecoration(
                          labelText: localizationService.translate('omm') ??
                              'Broj obračunskog mjernog mjesta (OMM)',
                        ),
                      ),
                      TextField(
                        controller: _serialController,
                        decoration: InputDecoration(
                          labelText:
                              localizationService.translate('serial_number') ??
                                  'Serijski broj brojila',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _saveOMMAndSerial,
                        child: Text(
                            localizationService.translate('save') ?? 'Pohrani'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (omm != null && serial != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '${localizationService.translate('omm') ?? 'OMM'}: $omm\n'
                  '${localizationService.translate('serial_number') ?? 'Serijski broj'}: $serial',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            TextField(
              controller: _tariff1Controller,
              decoration: InputDecoration(
                labelText:
                    localizationService.translate('tariff1') ?? 'Tarifa 1',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _tariff2Controller,
              decoration: InputDecoration(
                labelText:
                    localizationService.translate('tariff2') ?? 'Tarifa 2',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveReading,
              child: Text(localizationService.translate('save') ?? 'Pohrani'),
            ),
            const SizedBox(height: 16),
            if (locationAdmin)
              ElevatedButton(
                onPressed: _showAdminReadings,
                child: Text(
                  localizationService.translate('share_readings') ??
                      'Podijeli očitanja',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              localizationService.translate('reading_history') ??
                  'Povijest očitanja:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  locationAdmin ? _buildAdminReadings() : _buildUserReadings(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the list of readings for regular users
  Widget _buildUserReadings() {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return ListView.builder(
          itemCount: readings.length,
          itemBuilder: (context, index) {
            final reading = readings[index];
            final Timestamp timestamp = reading['timestamp'] as Timestamp;
            final DateTime dateTime = timestamp.toDate();
            final formattedDate =
                DateFormat('dd. MMMM yyyy., HH:mm\'h\'', 'hr').format(dateTime);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${localizationService.translate('tariff1') ?? 'Tarifa 1'}: ${reading['tariff1']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${localizationService.translate('tariff2') ?? 'Tarifa 2'}: ${reading['tariff2']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build the list of readings for administrators, grouped by month and last name
  Widget _buildAdminReadings() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _groupReadingsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error.toString()}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No readings available.'));
        } else {
          final groupedReadings = snapshot.data!;
          return ListView(
            children: groupedReadings.entries.map((monthEntry) {
              final String month = monthEntry.key;
              final Map<String, dynamic> users =
                  Map<String, dynamic>.from(monthEntry.value);

              return ExpansionTile(
                title: Text(month),
                children: users.entries.map((userEntry) {
                  final String lastName = userEntry.key;
                  final Map<String, dynamic> userData =
                      Map<String, dynamic>.from(userEntry.value);
                  final String omm = userData['omm'];
                  final String serial = userData['serial'];
                  final List<dynamic> userReadings =
                      List<dynamic>.from(userData['readings']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'OMM: $omm',
                        ),
                        Text(
                          'Serijski broj: $serial',
                        ),
                        const SizedBox(height: 8),
                        ...userReadings.map((reading) {
                          final DateTime timestamp = reading['timestamp'];
                          final String formattedDate =
                              DateFormat('dd. MMMM yyyy., HH:mm\'h\'', 'hr')
                                  .format(timestamp);
                          final String tariff1 = reading['tariff1'].toString();
                          final String tariff2 = reading['tariff2'].toString();

                          return Consumer<LocalizationService>(
                            builder: (context, localizationService, child) {
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${localizationService.translate('tariff1') ?? 'Tarifa 1'}: $tariff1',
                                      ),
                                      Text(
                                        '${localizationService.translate('tariff2') ?? 'Tarifa 2'}: $tariff2',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          );
        }
      },
    );
  }

  /// Group readings by month and last name for admin view
  Future<Map<String, dynamic>> _groupReadingsForAdmin() async {
    final user = _auth.currentUser;
    if (user == null || !locationAdmin) {
      return {};
    }

    try {
      // Fetch all users from location_users/{locationId}/users
      final usersSnapshot = await _firestore
          .collection('location_users')
          .doc(widget.locationId)
          .collection('users')
          .get();

      Map<String, dynamic> allReadings = {};

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = Map<String, dynamic>.from(userDoc.data());

        // Get lastName from /users/{userId}
        final userInfoDoc =
            await _firestore.collection('users').doc(userId).get();

        String lastName = 'Unknown';
        if (userInfoDoc.exists) {
          final userInfo = Map<String, dynamic>.from(userInfoDoc.data()!);
          lastName = userInfo['lastName'] ?? 'Unknown';
        }

        String omm = userData['omm'] ?? 'N/A';
        String serial = userData['serial'] ?? 'N/A';

        // Fetch readings for this user
        final readingsSnapshot = await _firestore
            .collection('location_users')
            .doc(widget.locationId)
            .collection('users')
            .doc(userId)
            .collection('readings')
            .orderBy('timestamp', descending: true)
            .get();

        for (var reading in readingsSnapshot.docs) {
          final readingData = Map<String, dynamic>.from(reading.data());

          DateTime timestamp = (readingData['timestamp'] as Timestamp).toDate();
          String month = DateFormat('MMMM yyyy', 'hr').format(timestamp);

          if (!allReadings.containsKey(month)) {
            allReadings[month] = {};
          }

          if (!allReadings[month].containsKey(lastName)) {
            allReadings[month][lastName] = {
              'omm': omm,
              'serial': serial,
              'readings': [],
            };
          }

          allReadings[month][lastName]['readings'].add({
            'timestamp': timestamp,
            'tariff1': readingData['tariff1'] ?? 0.0,
            'tariff2': readingData['tariff2'] ?? 0.0,
          });
        }
      }

      return allReadings;
    } catch (e) {
      debugPrint('Error grouping readings for admin: $e');
      return {};
    }
  }
}
