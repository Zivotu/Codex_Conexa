import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import '../services/location_service.dart' as loc_service;
import '../services/user_service.dart' as user_service;
import '../services/firebase_service.dart';
import '../services/navigation_service.dart';
import 'settings_screen.dart';
import 'create_location_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const HomeScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _locations = [];
  final user_service.UserService userService = user_service.UserService();
  final loc_service.LocationService locationService =
      loc_service.LocationService();
  final FirebaseService firebaseService = FirebaseService();
  final NavigationService navigationService = NavigationService();
  final Logger _logger = Logger();

  String _username = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUsername(),
      _fetchUserLocations(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsername() async {
    if (currentUser == null) return;
    final data = await userService.getUserDocument(currentUser!);
    if (mounted && data != null) {
      setState(() => _username = data['username'] ?? 'Unknown User');
    }
  }

  Future<void> _fetchUserLocations() async {
    if (currentUser == null) {
      _logger.e("Current user is null");
      return;
    }

    try {
      final data = await userService.getUserDocument(currentUser!);
      if (mounted && data != null) {
        final List<dynamic> locations = data['locations'] ?? [];
        _logger.i("User locations: $locations");

        final locationDocs = await Future.wait(locations.map((location) async {
          final locationId = location['locationId'];
          final countryId = location['countryId'];
          final cityId = location['cityId'];
          final deleted = location['deleted'] ?? false;

          if (locationId == null ||
              countryId == null ||
              cityId == null ||
              deleted) {
            _logger.w(
                "locationId, countryId, cityId is null or location is deleted for one of the locations");
            return null;
          }

          final locationData = await locationService.getLocationDocument(
              countryId, cityId, locationId);
          if (locationData != null && locationData['deleted'] == false) {
            return {
              'locationId': locationId,
              'locationName': locationData['name'] ?? 'Unnamed Location',
              'imagePath':
                  locationData['imagePath'] ?? 'assets/images/default_user.png',
              'createdBy': locationData['createdBy'] ?? 'Unknown Creator',
            };
          } else {
            _logger
                .w("Location $locationId is marked as deleted or not found.");
            return null;
          }
        }));

        if (mounted) {
          final uniqueLocations = <String, Map<String, dynamic>>{};
          for (var location in locationDocs.where((loc) => loc != null)) {
            uniqueLocations[location!['locationId']] = location;
          }
          setState(() => _locations = uniqueLocations.values.toList());
          _logger.i("Fetched locations: $_locations");

          if (_locations.length == 1 && _locations[0]['locationId'] != null) {
            Future.microtask(
                () => _navigateToLocation(_locations[0]['locationId']));
          }
        }
      } else {
        _logger.w("No data found for user");
      }
    } catch (e) {
      _logger.e("Error fetching user locations: $e");
    }
  }


  Future<void> _logEvent(String type, {String? locationId}) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('events').add({
      'type': type,
      'locationId': locationId,
      'userId': currentUser!.uid,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _showSnackBar(BuildContext context, String message) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onJoinLocation(BuildContext context) {
    showJoinLocationDialog(context).then((joined) {
      if (joined == true) {
        _fetchUserLocations();
      }
    });
  }

  Future<bool?> showJoinLocationDialog(BuildContext context) async {
    final TextEditingController linkController = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prijavi se u lokaciju'),
        content: TextField(
          controller: linkController,
          decoration: const InputDecoration(hintText: 'Unesite link lokacije'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ODUSTANI')),
          TextButton(
            onPressed: () {
              String link = linkController.text.trim();
              _handleLocationJoin(link, context);
            },
            child: const Text('PRIJAVI SE'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationJoin(String link, BuildContext context) async {
    if (link.isEmpty) return;

    try {
      final globalLocationDocs = await FirebaseFirestore.instance
          .collection('all_locations')
          .where('link', isEqualTo: link)
          .where('deleted', isEqualTo: false)
          .get();

      if (globalLocationDocs.docs.isNotEmpty) {
        final locationDoc = globalLocationDocs.docs.first;
        final locationId = locationDoc.id;
        final locationData = locationDoc.data();

        await _addUserToLocation(locationId, locationData);
        if (context.mounted) Navigator.of(context).pop(true);
      } else {
        if (context.mounted) {
          Navigator.of(context).pop(false);
          _showSnackBar(context, 'Lokacija nije pronađena');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(false);
        _showSnackBar(context, 'Greška pri prijavi u lokaciju: $e');
      }
    }
  }

  Future<void> _addUserToLocation(
      String locationId, Map<String, dynamic> locationData) async {
    if (currentUser == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    final userDoc = await userRef.get();
    final userLocations =
        List<Map<String, dynamic>>.from(userDoc['locations'] ?? []);
    final locationExists =
        userLocations.any((location) => location['locationId'] == locationId);

    if (locationExists) {
      await userRef.update({
        'locations': userLocations.map((location) {
          if (location['locationId'] == locationId) {
            location['status'] = 'joined';
            location['joinedAt'] = Timestamp.now();
            location['deleted'] = false;
          }
          return location;
        }).toList(),
      });
    } else {
      await userRef.update({
        'locations': FieldValue.arrayUnion([
          {
            'locationId': locationId,
            'locationName': locationData['name'] ?? 'Unnamed Location',
            'countryId': locationData['country'],
            'cityId': locationData['city'],
            'status': 'joined',
            'joinedAt': Timestamp.now(),
            'deleted': false,
          }
        ]),
      });
    }

    final locationRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(locationData['country'])
        .collection('cities')
        .doc(locationData['city'])
        .collection('locations')
        .doc(locationId)
        .collection('users')
        .doc(currentUser!.uid);

    final userData = await userService.getUserDocument(currentUser!);

    await locationRef.set({
      'userId': currentUser!.uid,
      'username': userData!['username'],
      'displayName': userData['displayName'],
      'email': userData['email'],
      'profileImageUrl': userData['profileImageUrl'],
      'locationAdmin': false,
      'deleted': false,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _logEvent('join', locationId: locationId);

    setState(() {
      if (!_locations.any((loc) => loc['locationId'] == locationId)) {
        _locations.add({
          'locationId': locationId,
          'locationName': locationData['name'] ?? 'Unnamed Location',
          'imagePath':
              locationData['imagePath'] ?? 'assets/images/default_user.png',
          'createdBy': locationData['createdBy'] ?? 'Unknown Creator',
        });
      }
    });
  }

  Future<bool?> showLeaveLocationDialog(
      BuildContext context, String locationId, String createdBy) async {
    final bool isCreator = createdBy == currentUser!.uid;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCreator
            ? 'Odaberite opciju za $locationId'
            : 'Jeste li sigurni da želite napustiti lokaciju $locationId?'),
        actions: isCreator
            ? [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('ODJAVI SE')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('IZBRIŠI LOKACIJU')),
              ]
            : [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('NE')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('DA')),
              ],
      ),
    );
  }

  void _navigateToLocation(String locationId) {
    final displayName = currentUser?.displayName ?? 'Unknown User';
    Navigator.pushNamed(
      context,
      '/locationDetails',
      arguments: {
        'countryId': widget.countryId,
        'cityId': widget.cityId,
        'locationId': locationId,
        'username': _username,
        'displayName': displayName,
      },
    ).then((_) => _fetchUserLocations());
  }

  void _navigateToSettings() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettingsScreen(
            username: _username,
            countryId: widget.countryId,
            cityId: widget.cityId,
            locationId: widget.locationId,
            locationAdmin: false, // Dodajte ovo
          ),
        ));
  }

  void _navigateToGroupChat(String locationId) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'username': _username,
        'locationId': locationId,
        'countryId': widget.countryId,
        'cityId': widget.cityId,
      },
    );
  }

  void _navigateToCreateLocation() {
    _checkBalanceAndNavigate(context);
  }

  Future<void> _checkBalanceAndNavigate(BuildContext context) async {
    if (currentUser == null) return;

    final user = currentUser;
    final data = await userService.getUserDocument(user!);
    if (context.mounted && data != null) {
      final balance = data['balance'] ?? 0;
      if (balance >= 50) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateLocationScreen(
              username: _username,
              countryId: widget.countryId,
              cityId: widget.cityId,
              locationId: widget.locationId,
            ),
          ),
        ).then((result) {
          if (result != null &&
              result is Map<String, dynamic> &&
              context.mounted) {
            setState(() {
              if (!_locations
                  .any((loc) => loc['locationId'] == result['locationId'])) {
                _locations.add(result);
              }
              _navigateToLocation(result['locationId']);
            });
          }
        });
      } else {
        _showSnackBar(context, 'Nedovoljno sredstava za kreiranje lokacije');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexa.life'),
        actions: [
          Center(child: Text(_username)),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ElevatedButton(
                  onPressed: () => _onJoinLocation(context),
                  child: const Text('Prijavi se u lokaciju'),
                ),
                Expanded(
                  child: _locations.isEmpty
                      ? Center(
                          child: ElevatedButton(
                            onPressed: _navigateToCreateLocation,
                            child: const Text('DODAJ LOKACIJU'),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            final location = _locations[index];
                            return Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onTap: () => _navigateToLocation(
                                        location['locationId']),
                                    child:
                                        location['imagePath'].startsWith('http')
                                            ? Image.network(
                                                location['imagePath'],
                                                fit: BoxFit.cover,
                                                height: 200,
                                              )
                                            : Image.asset(
                                                location['imagePath'],
                                                fit: BoxFit.cover,
                                                height: 200,
                                              ),
                                  ),
                                  ListTile(
                                    title: Text(location['locationName']),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chat),
                                          onPressed: () => _navigateToGroupChat(
                                              location['locationId']),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _navigateToLocation(
                                        location['locationId']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
