import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_details_screen.dart';
import '../services/location_service.dart';
import 'package:logger/logger.dart';
import '../services/localization_service.dart';
import 'package:provider/provider.dart';

class UsersScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const UsersScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  UsersScreenState createState() => UsersScreenState();
}

class UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _pendingUsers = [];
  String? _selectedLocationImage;
  bool _isLoadingImage = false;
  final LocationService locationService = LocationService();
  final Logger _logger = Logger();
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    _loadLocationImageAndName(widget.locationId);
    _loadPendingUsers(widget.locationId);
  }

  Future<void> _loadLocationImageAndName(String locationId) async {
    setState(() {
      _isLoadingImage = true;
    });
    try {
      final locationData = await locationService.getLocationDocument(
          widget.countryId, widget.cityId, locationId);
      setState(() {
        _locationName = locationData?['name'] ?? 'Nepoznata ime lokacije';
        _selectedLocationImage =
            locationData?['imagePath'] ?? 'assets/images/default_location.png';
        _isLoadingImage = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingImage = false;
      });
      _showErrorDialog('Greška pri učitavanju lokacije: $e');
    }
  }

  Future<void> _loadPendingUsers(String locationId) async {
    try {
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('location_users')
          .doc(locationId)
          .collection('pending_users')
          .get();

      List<Map<String, dynamic>> pendingUsers = [];
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data();
        pendingUsers.add(data);
      }

      if (mounted) {
        setState(() {
          _pendingUsers = pendingUsers;
        });
      }
    } catch (e) {
      _logger.e('Greška pri učitavanju pending_users: $e');
    }
  }

  Future<List<String>> _getUserIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('location_users')
        .doc(widget.locationId)
        .collection('users')
        .get();
    return snapshot.docs
        .map((doc) => doc.data()['userId'] as String?)
        .whereType<String>()
        .toList();
  }

  // Metode za odobravanje i odbijanje zahtjeva (ostaju nepromijenjene)
  Future<void> _approveRequest(Map<String, dynamic> pendingUser) async {
    // ... postojeća logika odobravanja zahtjeva
  }

  Future<void> _rejectRequest(Map<String, dynamic> pendingUser) async {
    // ... postojeća logika odbijanja zahtjeva
  }

  void _showErrorDialog(String message) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizationService.translate('error') ?? 'Greška'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizationService.translate('ok') ?? 'OK'),
            ),
          ],
        );
      },
    );
  }

  // Nova metoda za kick korisnika, poziva userService metodu
  Future<void> _kickUser(String userId) async {
    try {
      await locationService.userService
          .kickUserFromLocation(userId, widget.locationId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Korisnik je izbačen iz lokacije.')),
      );
      setState(() {}); // refresh UI
    } catch (e) {
      _logger.e('Greška pri izbacivanju korisnika: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri izbacivanju korisnika: $e')),
      );
    }
  }

  // Nova metoda za unblock korisnika, poziva userService metodu
  Future<void> _unblockUser(String userId) async {
    try {
      await locationService.userService
          .unblockUserFromLocation(userId, widget.locationId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Korisnik je odblokiran.')),
      );
      setState(() {}); // refresh UI
    } catch (e) {
      _logger.e('Greška pri odblokiranju korisnika: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri odblokiranju korisnika: $e')),
      );
    }
  }

  // Metoda za prikaz popup-a sa zahtjevima na čekanju
  void _showPendingRequests() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizationService.translate('pendingRequests') ??
              'zahtjevi na čekanju'),
          content: SizedBox(
            width: double.maxFinite,
            child: _pendingUsers.isEmpty
                ? Text(localizationService.translate('noPendingRequests') ??
                    'Nema zahtjeva za odobrenje.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _pendingUsers.length,
                    itemBuilder: (context, index) {
                      final pendingUser = _pendingUsers[index];
                      final profileImageUrl =
                          (pendingUser['profileImageUrl'] as String?) ?? '';
                      final firstName = pendingUser['displayName'] ?? '';
                      final lastName = pendingUser['lastName'] ?? '';
                      final fullName = (firstName + ' ' + lastName).trim();
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6.0, horizontal: 10.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileImageUrl.isNotEmpty
                                ? (profileImageUrl.startsWith('http')
                                    ? NetworkImage(profileImageUrl)
                                    : AssetImage(profileImageUrl)
                                        as ImageProvider)
                                : const AssetImage(
                                    'assets/images/default_user.png'),
                          ),
                          title: Text(fullName.isNotEmpty
                              ? fullName
                              : localizationService.translate('unknownUser') ??
                                  'Nepoznat'),
                          subtitle: Text(pendingUser['email'] ??
                              localizationService.translate('noEmail') ??
                              'Nepoznat email'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                onPressed: () {
                                  _approveRequest(pendingUser);
                                  Navigator.of(context).pop();
                                },
                                tooltip:
                                    localizationService.translate('approve') ??
                                        'Odobri',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  _rejectRequest(pendingUser);
                                  Navigator.of(context).pop();
                                },
                                tooltip:
                                    localizationService.translate('reject') ??
                                        'Odbij',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizationService.translate('ok') ?? 'OK'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('users') ?? 'Korisnici'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _isLoadingImage
              ? const CircularProgressIndicator()
              : _selectedLocationImage != null
                  ? Container(
                      height: 150,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: _selectedLocationImage!.startsWith('http')
                              ? NetworkImage(_selectedLocationImage!)
                              : AssetImage(_selectedLocationImage!)
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _getUserIds(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Greška pri učitavanju korisnika.'));
                }
                final userIds = snapshot.data ?? [];
                if (userIds.isEmpty) {
                  return Center(
                    child: Text(localizationService.translate('noUsers') ??
                        'Nema korisnika'),
                  );
                }
                return ListView.builder(
                  itemCount: userIds.length,
                  itemBuilder: (context, index) {
                    final userId = userIds[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('location_users')
                          .doc(widget.locationId)
                          .collection('users')
                          .doc(userId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(title: Text('Učitavanje...'));
                        }
                        if (userSnapshot.hasError ||
                            !userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return ListTile(
                              title: Text(localizationService
                                      .translate('error_loading_user') ??
                                  'Greška pri učitavanju korisnika'));
                        }
                        final data =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        // Ako u dokumentu iz location_users nedostaje lastName, dohvaćamo ga iz root kolekcije 'users'
                        return FutureBuilder<DocumentSnapshot?>(
                          future: (data['lastName'] != null &&
                                  (data['lastName'] as String)
                                      .trim()
                                      .isNotEmpty)
                              ? Future.value(null)
                              : FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                          builder: (context, fallbackSnapshot) {
                            String lastName = data['lastName'] ?? '';
                            if (fallbackSnapshot.hasData &&
                                fallbackSnapshot.data != null &&
                                fallbackSnapshot.data!.exists) {
                              final fallbackData = fallbackSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              if (((fallbackData['lastName'] as String?) ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                lastName = fallbackData['lastName'];
                              }
                            }
                            final firstName = data['displayName'] ?? '';
                            final fullName =
                                (firstName + ' ' + lastName).trim();
                            final profileImageUrl =
                                (data['profileImageUrl'] as String?)?.trim() ??
                                    '';
                            final status = data['status'] ?? 'joined';

                            return Card(
                              margin: const EdgeInsets.all(10.0),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserDetailsScreen(
                                        userData: data,
                                        userId: userId,
                                        locationId: widget.locationId,
                                        countryId: widget.countryId,
                                        cityId: widget.cityId,
                                      ),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundImage: profileImageUrl.isNotEmpty
                                      ? (profileImageUrl.startsWith('http')
                                          ? NetworkImage(profileImageUrl)
                                          : AssetImage(profileImageUrl)
                                              as ImageProvider)
                                      : const AssetImage(
                                          'assets/images/default_user.png'),
                                ),
                                title: Text(fullName.isNotEmpty
                                    ? fullName
                                    : localizationService
                                            .translate('unknownUser') ??
                                        'Korisnik'),
                                subtitle: Text(data['email'] ??
                                    localizationService.translate('noEmail') ??
                                    'Nepoznat email'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    status != 'kicked'
                                        ? IconButton(
                                            icon: const Icon(Icons.lock),
                                            color: Colors.red,
                                            tooltip: 'Izbaci korisnika',
                                            onPressed: () => _kickUser(userId),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.lock_open),
                                            color: Colors.green,
                                            tooltip: 'Odblokiraj korisnika',
                                            onPressed: () =>
                                                _unblockUser(userId),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: _showPendingRequests,
          child: Text(localizationService.translate('pendingRequests') ??
              'zahtjevi na čekanju'),
        ),
      ),
    );
  }
}
