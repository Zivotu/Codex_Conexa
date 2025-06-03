import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/subscription_service.dart';
import '../services/location_service.dart' as loc_service;
import '../services/user_service.dart' as user_service;
import '../services/localization_service.dart';
import 'review_location_screen.dart';

const kGoogleApiKey = "AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM";

class CreateLocationScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const CreateLocationScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  State<CreateLocationScreen> createState() => CreateLocationScreenState();
}

class CreateLocationScreenState extends State<CreateLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  double? _latitude;
  double? _longitude;

  String _locationName = '';
  String _locationAddress = '';
  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedCountryCode;
  File? _selectedImage;
  bool _useDemoData = true;
  bool _isLoading = false;

  String? _locationId;
  final TextEditingController _cityController = TextEditingController();

  String _activationType = ''; // 'active', 'trial', 'inactive'
  Timestamp? _activeUntil;

  bool _showIntro = true;

  // Servisi
  final loc_service.LocationService _locationService =
      loc_service.LocationService();
  final user_service.UserService userService = user_service.UserService();

  // ------------------------------
  // VARIJABLE ZA AFFILIATE / BONUS KOD
  // ------------------------------
  /// Spremamo bonus kod koji unese korisnik
  String _bonusCode = "";

  /// Provjeravamo je li trenutni user superadmin
  bool _isSuperAdmin = false;

  // Kontroleri za kreiranje novog partner koda
  final TextEditingController _partnerFirstNameController =
      TextEditingController();
  final TextEditingController _partnerLastNameController =
      TextEditingController();
  final TextEditingController _partnerEmailController = TextEditingController();
  final TextEditingController _partnerBonusCodeController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIfSuperAdmin();
    _locationId = null;
    _checkUserLocationsLimit();
    _fetchCurrentSubscription();
  }

  Future<void> _checkIfSuperAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;

    bool isSuper = doc.data()?["superadmin"] ?? false;

    setState(() {
      _isSuperAdmin = isSuper;
    });
  }

  Future<int> _getOwnedLocationsCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('owned_locations')
        .where('deleted', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  Future<void> _checkUserLocationsLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _getOwnedLocationsCount(user.uid);
  }

  Future<void> _fetchCurrentSubscription() async {
    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    await subscriptionService.loadCurrentSubscription();
  }

  /// Uvodni ekran
  Widget _buildIntroScreen(LocalizationService localizationService) {
    final modules = [
      {
        'title': localizationService.translate('module_chat_title'),
        'description': localizationService.translate('module_chat_description'),
        'icon': Icons.chat,
      },
      {
        'title': localizationService
            .translate('module_official_announcements_title'),
        'description': localizationService
            .translate('module_official_announcements_description'),
        'icon': Icons.campaign,
      },
      {
        'title': localizationService.translate('module_neighborhood_title'),
        'description':
            localizationService.translate('module_neighborhood_description'),
        'icon': Icons.location_city,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('intro_title'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade300,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final module = modules[index];
          return Column(
            children: [
              _buildModuleCard(
                title: module['title'] as String,
                description: module['description'] as String,
                icon: module['icon'] as IconData,
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showIntro = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              localizationService.translate('create_location'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen(LocalizationService localizationService) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('create_new_location'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade300,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCreateLocationForm(localizationService),

                // Ako je superadmin, prikažemo poseban formular
                if (_isSuperAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 30.0),
                    child: _buildAffiliateBonusCodeForm(localizationService),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 60, color: Colors.teal.shade700),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateLocationForm(LocalizationService localizationService) {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: localizationService.translate('location_name'),
                  prefixIcon:
                      const Icon(Icons.location_on, color: Colors.white),
                  filled: true,
                  fillColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizationService.translate('enter_location_name');
                  }
                  return null;
                },
                onSaved: (val) => _locationName = val ?? '',
              ),
              const SizedBox(height: 20),
              Autocomplete<Map<String, String>>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.length < 3) {
                    return const Iterable<Map<String, String>>.empty();
                  }
                  try {
                    return await fetchCityAndCountry(textEditingValue.text);
                  } catch (e) {
                    return const Iterable<Map<String, String>>.empty();
                  }
                },
                displayStringForOption: (option) => option['city'] ?? '',
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  fieldTextEditingController.text = _cityController.text;
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: localizationService.translate('enter_city'),
                      prefixIcon:
                          const Icon(Icons.location_city, color: Colors.white),
                      filled: true,
                      fillColor: Colors.teal.shade50,
                      labelStyle: TextStyle(color: Colors.teal.shade700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (_selectedCity == null || _selectedCity!.isEmpty) {
                        return localizationService
                            .translate('please_enter_city');
                      }
                      return null;
                    },
                  );
                },
                onSelected: (Map<String, String> selection) {
                  _cityController.text = selection['city'] ?? '';
                  setState(() {
                    _selectedCity = selection['city'];
                    _selectedCountry = selection['country'];
                    _selectedCountryCode = selection['countryCode'];
                  });
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  labelText: localizationService.translate('location_address'),
                  prefixIcon: const Icon(Icons.home, color: Colors.white),
                  filled: true,
                  fillColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => _locationAddress = val,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return localizationService.translate('enter_address');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Bonus code (opcionalno)
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Bonus code (opcionalno)",
                  prefixIcon:
                      const Icon(Icons.card_giftcard, color: Colors.white),
                  filled: true,
                  fillColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  // Konvertiramo u mala slova
                  _bonusCode = val.trim().toLowerCase();
                },
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkLocation,
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(localizationService.translate('check_location')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label:
                      Text(localizationService.translate('add_location_image')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedImage != null)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (_selectedImage != null) const SizedBox(height: 20),
              SwitchListTile(
                title: Text(
                  localizationService.translate('demo_data'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        localizationService.translate('demo_data_description')),
                    const SizedBox(height: 4),
                    Text(
                      localizationService
                          .translate('demo_data_supported_langs'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                value: _useDemoData,
                onChanged: (val) => setState(() => _useDemoData = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _reviewAndConfirmLocation,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(localizationService.translate('continue')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, String>>> fetchCityAndCountry(String input) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
      'input=${Uri.encodeComponent(input)}&types=(cities)&key=$kGoogleApiKey',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final predictions = data['predictions'] as List<dynamic>;
      List<Map<String, String>> suggestions = [];
      for (var prediction in predictions) {
        final placeId = prediction['place_id'] as String;
        final detailsUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId'
          '&fields=name,geometry,address_component&key=$kGoogleApiKey',
        );
        final detailsResp =
            await http.get(detailsUrl).timeout(const Duration(seconds: 10));
        if (detailsResp.statusCode == 200) {
          final detailsData = json.decode(detailsResp.body);
          if (detailsData['result'] != null) {
            final addressComponents =
                detailsData['result']['address_components'] as List<dynamic>;
            String city = '', country = '', countryCode = '';
            for (final c in addressComponents) {
              final types = c['types'] as List<dynamic>;
              if (types.contains('locality')) {
                city = c['long_name'] as String;
              }
              if (types.contains('country')) {
                country = c['long_name'] as String;
                countryCode = c['short_name'] as String;
              }
            }
            if (city.isNotEmpty &&
                country.isNotEmpty &&
                countryCode.isNotEmpty) {
              suggestions.add({
                'city': city,
                'country': country,
                'countryCode': countryCode,
              });
            }
          }
        }
      }
      return suggestions;
    } else {
      throw Exception('Failed to fetch city & country');
    }
  }

  Future<void> _checkLocation() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    if (_locationAddress.isEmpty || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(localizationService.translate('enter_address_and_city'))),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=${Uri.encodeComponent(_locationAddress)},${Uri.encodeComponent(_selectedCity!)}'
        '&key=$kGoogleApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          _latitude = loc['lat'];
          _longitude = loc['lng'];
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) =>
                  StaticMapWidget(latitude: _latitude!, longitude: _longitude!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(localizationService.translate('address_not_found'))),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  localizationService.translate('error_fetching_coordinates'))),
        );
      }
    } catch (e) {
      _logger.e('Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${localizationService.translate('error')}: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  Future<void> _reviewAndConfirmLocation() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localizationService.translate('user_not_logged_in'))),
      );
      return;
    }

    final subscriptionService =
        Provider.of<SubscriptionService>(context, listen: false);
    await subscriptionService.loadCurrentSubscription();
    int maxSlots = subscriptionService.slotCount;
    int ownedLocations = await _getOwnedLocationsCount(user.uid);

    // Ako je bonus kod unesen, pokušavamo ga validirati
    if (_bonusCode.isNotEmpty) {
      bool validBonus = await _validateAndApplyBonusCode();

      if (validBonus) {
        _activationType = 'active';
        // 30 dana besplatno
        _activeUntil =
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizationService.translate('invalid_bonus_code')),
          ),
        );
        return;
      }
    } else {
      // Stara logika ako nema bonus koda
      if (ownedLocations >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  localizationService.translate('max_location_limit_reached'))),
        );
        return;
      }

      if (maxSlots > ownedLocations) {
        _activationType = 'active';
        _activeUntil = Timestamp.fromDate(
          subscriptionService.getCurrentSubscriptionEndDate()!,
        );
      } else {
        bool trialExists = await _locationService.trialLocationExists(user.uid);
        if (!trialExists) {
          _activationType = 'trial';
          _activeUntil =
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));
          await showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: Text(localizationService.translate('trial_title')),
                content: Text(localizationService.translate('trial_message')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(localizationService.translate('ok')),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    localizationService.translate('error_no_trial_available'))),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);
    try {
      _locationId ??=
          FirebaseFirestore.instance.collection('locations').doc().id;
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }
      imageUrl ??=
          'assets/images/locations/location${Random().nextInt(9) + 1}.png';

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReviewLocationScreen(
            locationId: _locationId!,
            locationName: _locationName,
            locationAddress: _locationAddress,
            city: _selectedCity!,
            country: _selectedCountry ?? '',
            year: DateTime.now().year,
            selectedImagePath: imageUrl ?? '',
            onConfirm: _createLocation,
            username: widget.username,
            activationType: _activationType,
            activeUntil: _activeUntil?.toDate().toString(),
          ),
        ),
      );
    } catch (e) {
      _logger.e('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${localizationService.translate('error')}: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _validateAndApplyBonusCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('affiliate_bonus_codes')
          .where('code', isEqualTo: _bonusCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      final List<dynamic> redeemedBy = data['redeemedBy'] ?? [];

      // Ako je korisnik već iskoristio kod – odbij
      if (redeemedBy.contains(user.uid)) {
        return false;
      }

      // Ažuriraj dokument – dodaj korisnika, povećaj redemptions i postavi active: true
      await doc.reference.update({
        'redeemedBy': FieldValue.arrayUnion([user.uid]),
        'redemptions': FieldValue.increment(1),
        'lastRedeemedAt': Timestamp.now(),
        'active': true, // automatski aktiviramo kod
      });

      return true;
    } catch (e) {
      _logger.e("Error validating bonus code: $e");
      return false;
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final tmpId = _locationId ??
          FirebaseFirestore.instance.collection('locations').doc().id;
      final fileName = 'locations/$tmpId.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final task = ref.putFile(imageFile);
      final snap = await task;
      final downloadUrl = await snap.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _logger.e('Upload Error: $e');
      return null;
    }
  }

  Future<void> _createLocation() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localizationService.translate('user_not_logged_in'))),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      _locationId ??=
          FirebaseFirestore.instance.collection('locations').doc().id;
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }
      imageUrl ??=
          'assets/images/locations/location${Random().nextInt(9) + 1}.png';

      final locationData = {
        'id': _locationId,
        'name': _locationName,
        'address': _locationAddress,
        'link': _locationId,
        'city': _selectedCity,
        'country': _selectedCountry,
        'countryCode': _selectedCountryCode,
        'latitude': _latitude,
        'longitude': _longitude,
        'year': DateTime.now().year,
        'createdBy': user.uid,
        'ownedBy': user.uid,
        'imagePath': imageUrl,
        'useDemoData': _useDemoData,
        'requiresApproval': false,
        'activationType': _activationType,
        'activeUntil': _activeUntil,
        'attachedPaymentId': null,
        'trialPeriod': _activationType == 'trial',
        'createdAt': FieldValue.serverTimestamp(),
        // Ako je bonus code bio iskorišten, spremimo ga
        'bonusCode': _bonusCode.isNotEmpty ? _bonusCode : null,
      };

      final locationRef =
          FirebaseFirestore.instance.collection('locations').doc(_locationId);
      await locationRef.set(locationData);

      final countryCityLocationRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_selectedCountry)
          .collection('cities')
          .doc(_selectedCity)
          .collection('locations')
          .doc(_locationId);
      await countryCityLocationRef.set(locationData);

      if (_useDemoData) {
        await _copyDemoData(user.uid);
      }

      final userLocationRef = FirebaseFirestore.instance
          .collection('user_locations')
          .doc(user.uid)
          .collection('locations')
          .doc(_locationId);
      final userLocationData = {
        'locationId': _locationId,
        'locationName': _locationName,
        'countryId': _selectedCountry,
        'cityId': _selectedCity,
        'joinedAt': Timestamp.now(),
        'locationAdmin': true,
        'deleted': false,
        'status': 'joined',
        'imagePath': imageUrl,
        'activationType': _activationType,
        'activeUntil': _activeUntil,
        'attachedPaymentId': null,
        'trialPeriod': _activationType == 'trial',
        'ownedBy': user.uid,
      };
      await userLocationRef.set(userLocationData);

      final ownedLocationRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('owned_locations')
          .doc(_locationId);
      await ownedLocationRef.set(locationData);

      await FirebaseFirestore.instance
          .collection('location_users')
          .doc(_locationId)
          .collection('users')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'username': widget.username,
        'displayName': widget.username,
        'email': user.email ?? '',
        'profileImageUrl': 'assets/images/default_user.png',
        'joinedAt': Timestamp.now(),
        'deleted': false,
        'locationAdmin': true,
        'fcmToken': await userService.getFCMToken(user) ?? '',
      });

      await userService.addLocationToUser(user.uid, userLocationData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(localizationService.translate('location_created_success')),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _logger.e('Error creating location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${localizationService.translate('error')}: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Metode za demo data
  Future<Map<String, dynamic>> _loadDemoLangJson() async {
    final jsonString =
        await rootBundle.loadString('assets/demo_lang/demo_lang.json');
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _loadDemoBulletinJson() async {
    final jsonString =
        await rootBundle.loadString('assets/demo_lang/demo_bulletin.json');
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  Future<void> _copyDemoData(String userId) async {
    try {
      await _copyDemoBlogData(userId);
      await _copyDemoBulletinData(userId);
      _logger.i('All demo data copied successfully.');
    } catch (e) {
      _logger.e('Error copying demo data: $e');
    }
  }

  Future<void> _copyDemoBlogData(String userId) async {
    try {
      final demoData = await _loadDemoLangJson();
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      final currentLang = localizationService.currentLanguage.toLowerCase();

      final blog = demoData['blog'] as Map<String, dynamic>?;
      if (blog == null) {
        _logger.w('Blog data not found in demo_lang.json');
        return;
      }

      final blogTitle = blog['title'][currentLang] ?? blog['title']['en'];
      final blogAuthor = blog['author'][currentLang] ?? blog['author']['en'];
      final blogContent = blog['content'][currentLang] ?? blog['content']['en'];
      final pollQuestion =
          blog['pollQuestion'][currentLang] ?? blog['pollQuestion']['en'];
      final pollOptions =
          blog['pollOptions'][currentLang] ?? blog['pollOptions']['en'] ?? [];

      final newBlogRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_selectedCountry)
          .collection('cities')
          .doc(_selectedCity)
          .collection('locations')
          .doc(_locationId)
          .collection('blogs')
          .doc();

      final blogDoc = {
        'title': blogTitle,
        'author': blogAuthor,
        'content': blogContent,
        'pollQuestion': pollQuestion,
        'pollOptions': List.generate(
          pollOptions.length,
          (i) => {
            'option': pollOptions[i],
            'votes': 0,
          },
        ),
        'createdAt': Timestamp.now(),
        'createdBy': userId,
        'dislikedUsers': [],
        'dislikes': 0,
        'imageUrls': [],
        'likedUsers': [],
        'likes': 0,
        'shares': 0,
        'votedUsers': [],
      };

      await newBlogRef.set(blogDoc);
      _logger.i('Demo blog successfully created for language $currentLang.');
    } catch (e) {
      _logger.e('Error copying demo blog: $e');
    }
  }

  Future<void> _copyDemoBulletinData(String userId) async {
    try {
      final bulletinData = await _loadDemoBulletinJson();
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      final currentLang = localizationService.currentLanguage.toLowerCase();

      final bulletin = bulletinData['bulletin'] as Map<String, dynamic>?;
      if (bulletin == null) {
        _logger.w('Bulletin data not found in demo_bulletin.json');
        return;
      }

      final bTitle = bulletin['title'][currentLang] ?? bulletin['title']['en'];
      final bDescription =
          bulletin['description'][currentLang] ?? bulletin['description']['en'];
      final bImagePath =
          bulletin['imagePath'][currentLang] ?? bulletin['imagePath']['en'];

      double lat = 0.0;
      double lng = 0.0;
      final buildingDoc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(_selectedCountry)
          .collection('cities')
          .doc(_selectedCity)
          .collection('locations')
          .doc(_locationId)
          .get();

      if (buildingDoc.exists) {
        final data = buildingDoc.data()!;
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          lat = (data['latitude'] as num).toDouble();
          lng = (data['longitude'] as num).toDouble();
        } else if (data.containsKey('coordinates')) {
          final coords = data['coordinates'];
          if (coords is Map &&
              coords.containsKey('lat') &&
              coords.containsKey('lng')) {
            lat = (coords['lat'] as num).toDouble();
            lng = (coords['lng'] as num).toDouble();
          }
        }
      }

      final newBulletinRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(_selectedCountry)
          .collection('cities')
          .doc(_selectedCity)
          .collection('locations')
          .doc(_locationId)
          .collection('bulletin_board')
          .doc();

      final bulletinDoc = {
        'id': newBulletinRef.id,
        'title': bTitle,
        'description': bDescription,
        'imagePaths': [bImagePath],
        'likes': 0,
        'dislikes': 0,
        'userLiked': false,
        'userDisliked': false,
        'comments': [],
        'createdAt': Timestamp.now(),
        'createdBy': userId,
        'location': GeoPoint(lat, lng),
        'radius': 0.0,
        'isInternal': true,
        'expired': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 15)),
        ),
      };

      await newBulletinRef.set(bulletinDoc);
      _logger
          .i('Demo bulletin successfully created for language $currentLang.');
    } catch (e) {
      _logger.e('Error copying demo bulletin: $e');
    }
  }

  /// Formular za superadmina za kreiranje partner koda
  Widget _buildAffiliateBonusCodeForm(LocalizationService localizationService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizationService.translate('affiliate_bonus_code'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _partnerFirstNameController,
              decoration: InputDecoration(
                labelText: localizationService.translate('partner_first_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _partnerLastNameController,
              decoration: InputDecoration(
                labelText: localizationService.translate('partner_last_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _partnerEmailController,
              decoration: InputDecoration(
                labelText: localizationService.translate('partner_email'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _partnerBonusCodeController,
              decoration: InputDecoration(
                labelText: localizationService.translate('bonus_code'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onChanged: (val) {
                // Konvertiraj u mala slova
                final lower = val.toLowerCase();
                _partnerBonusCodeController.value = TextEditingValue(
                  text: lower,
                  selection: TextSelection.collapsed(offset: lower.length),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createAffiliateBonusCode,
                child:
                    Text(localizationService.translate('activate_bonus_code')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAffiliateBonusCode() async {
    String bonusCode = _partnerBonusCodeController.text.trim().toLowerCase();
    if (bonusCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bonus kod je obavezan.")),
      );
      return;
    }
    // Provjera jedinstvenosti
    final querySnapshot = await FirebaseFirestore.instance
        .collection('affiliate_bonus_codes')
        .where('code', isEqualTo: bonusCode)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bonus kod već postoji.")),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('affiliate_bonus_codes').add({
      'code': bonusCode,
      'partnerFirstName': _partnerFirstNameController.text.trim(),
      'partnerLastName': _partnerLastNameController.text.trim(),
      'partnerEmail': _partnerEmailController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
      'redeemedBy': [],
      'redemptions': 0,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bonus kod uspješno aktiviran.")),
    );
    _partnerFirstNameController.clear();
    _partnerLastNameController.clear();
    _partnerEmailController.clear();
    _partnerBonusCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);
    return _showIntro
        ? _buildIntroScreen(localizationService)
        : _buildMainScreen(localizationService);
  }
}

// Ovaj widget ostaje nepromijenjen
class StaticMapWidget extends StatelessWidget {
  final double latitude;
  final double longitude;

  const StaticMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final staticMapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=$latitude,$longitude'
        '&zoom=13&size=600x300&maptype=roadmap'
        '&markers=color:red%7Clabel:L%7C$latitude,$longitude'
        '&key=$kGoogleApiKey';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('check_location'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade300,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                staticMapUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.teal));
                },
                errorBuilder: (ctx, error, stack) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      localizationService.translate('map_loading_failed'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: Text(localizationService.translate('ok')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
