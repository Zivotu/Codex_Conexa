// lib/screens/affiliate_supplement_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/affiliate_code.dart';

import '../services/event_logger.dart';
import '../services/localization_service.dart';
import 'user_locations_screen.dart';

class AffiliateSupplementScreen extends StatefulWidget {
  final String userId;
  const AffiliateSupplementScreen({super.key, required this.userId});

  @override
  _AffiliateSupplementScreenState createState() =>
      _AffiliateSupplementScreenState();
}

class _AffiliateSupplementScreenState extends State<AffiliateSupplementScreen> {
  final _formKey = GlobalKey<FormState>();
  // kontroleri - potpuno isti kao u registraciji
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _customCountryController = TextEditingController();
  final _customCityController = TextEditingController();

  XFile? _profileImage;
  String? _selectedPredefinedImage;
  String _country = 'Hrvatska';
  String _city = 'Zagreb';
  bool _isCustomCountry = false;
  bool _isCustomCity = false;
  String _selectedEducation = 'SSS - Srednja škola';
  String _selectedOccupation = 'Ostalo';

  bool _loading = false;
  final _log = Logger();
  final _eventLogger = EventLogger();

  final Map<String, List<String>> _countryCities = {
    'Hrvatska': [
      'Bjelovar',
      'Buzet',
      'Cavtat',
      'Dubrovnik',
      'Đakovo',
      'Gračanica',
      'Hrvatska Ves',
      'Karlovac',
      'Koprivnica',
      'Križevci',
      'Lika',
      'Metković',
      'Osijek',
      'Petrinja',
      'Požega',
      'Rijeka',
      'Samobor',
      'Sisak',
      'Slavonski Brod',
      'Solin',
      'Split',
      'Varaždin',
      'Velika Gorica',
      'Vinkovci',
      'Vukovar',
      'Zagreb',
      'Zadar',
      'Šibenik'
    ],
  };

  final List<String> _educationLevels = [
    'Osnovno obrazovanje',
    'SSS - Srednja škola',
    'VŠS - Viša stručna sprema',
    'VSS - Visoka stručna sprema',
    'Magisterij',
    'Doktorat',
    'Ostalo'
  ];

  final List<String> _occupations = [
    'Inženjer',
    'Programer',
    'Liječnik',
    'Učitelj',
    'Prodavač',
    'Vozač',
    'Administrativni radnik',
    'Menadžer',
    'Policajac',
    'Vatrogasac',
    'Ostalo'
  ];

  final List<String> _predefinedProfileImages = [
    'assets/images/Profile_pic_1.png',
    'assets/images/Profile_pic_2.png',
    'assets/images/Profile_pic_3.png',
    'assets/images/Profile_pic_4.png',
    'assets/images/Profile_pic_5.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingUser();
  }

  Future<void> _loadExistingUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = doc.data();
    if (data == null) return;

    // popuni sve kontrolere
    _emailController.text = data['email'] ?? '';
    _usernameController.text = data['username'] ?? '';
    _displayNameController.text = data['displayName'] ?? '';
    _lastNameController.text = data['lastName'] ?? '';
    _floorController.text = data['floor'] ?? '';
    _apartmentNumberController.text = data['apartmentNumber'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _addressController.text = data['address'] ?? '';
    _ageController.text = (data['age']?.toString() ?? '');
    _country = data['countryId'] ?? _country;
    _city = data['cityId'] ?? _city;
    _selectedEducation = data['education'] ?? _selectedEducation;
    _selectedOccupation = data['occupation'] ?? _selectedOccupation;
    if (data['profileImageUrl'] is String) {
      final url = data['profileImageUrl'] as String;
      if (_predefinedProfileImages.contains(url)) {
        _selectedPredefinedImage = url;
      } else {
        // možemo ignorirati ili postaviti thumbnail…
      }
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    setState(() {
      _profileImage = f;
      _selectedPredefinedImage = null;
    });
  }

  Widget _buildField({
    required TextEditingController ctl,
    required String label,
    bool readOnly = false,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: ctl,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String label,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
          .toList(),
      onChanged: onChanged,
      validator: validator != null ? (v) => validator(v) : null,
    );
  }

  Future<String?> _getDeviceId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('device_id') ?? 'unknown';
  }

  Future<void> _onFinish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = _emailController.text.trim();
      final uid = widget.userId;

      // 1) upload slike ako ima
      String? profileUrl;
      if (_profileImage != null) {
        final ref =
            FirebaseStorage.instance.ref().child('user_images/$uid.jpg');
        final task = kIsWeb
            ? ref.putData(await _profileImage!.readAsBytes())
            : ref.putFile(File(_profileImage!.path));
        await task;
        profileUrl = await ref.getDownloadURL();
      } else if (_selectedPredefinedImage != null) {
        profileUrl = _selectedPredefinedImage;
      }

      // 2) update korisnika
      final pkg = await PackageInfo.fromPlatform();
      final deviceId = await _getDeviceId();
      final userData = {
        'email': email,
        'username': _usernameController.text.trim(),
        'displayName': _displayNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'floor': _floorController.text.trim(),
        'apartmentNumber': _apartmentNumberController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'age': int.tryParse(_ageController.text),
        'countryId':
            _isCustomCountry ? _customCountryController.text.trim() : _country,
        'cityId': _isCustomCity ? _customCityController.text.trim() : _city,
        'education': _selectedEducation,
        'occupation': _selectedOccupation,
        'profileImageUrl': profileUrl,
        'appVersion': pkg.version,
        'deviceId': deviceId,
        'affiliateActive': true,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(userData);

      // 3) log event
      await _eventLogger.logEvent('user_become_affiliate', {
        'userId': uid,
      });

      // 4) kreiraj affiliate kod
      final code = generateAffiliateCode(
        _displayNameController.text.trim(),
        _lastNameController.text.trim(),
      );
      await FirebaseFirestore.instance.collection('affiliate_bonus_codes').add({
        'active': false,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'partnerEmail': email,
        'partnerFirstName': _displayNameController.text.trim(),
        'partnerLastName': _lastNameController.text.trim(),
        'redeemedBy': <String>[],
        'redemptions': 0,
        'userId': uid,
      });

      // 5) poruka i redirect
      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(loc.translate('affiliate_registered_title') ??
              'Postali ste naš partner!'),
          content: Text(loc.translate('affiliate_registered_message') ??
              'Hvala na partnerstvu!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserLocationsScreen(
                        username: _usernameController.text.trim()),
                  ),
                );
              },
              child: Text(loc.translate('ok') ?? 'OK'),
            )
          ],
        ),
      );
    } catch (e) {
      _log.e('Greška pri affiliate supplement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Došlo je do pogreške: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('affiliate_supplement_title') ??
            'Dodatni podaci za partnera'),
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildField(
                    ctl: _emailController,
                    label: loc.translate('email') ?? 'Email',
                    readOnly: true,
                  ),
                  _buildField(
                    ctl: _usernameController,
                    label: loc.translate('username') ?? 'Korisničko ime',
                    readOnly: true,
                  ),
                  _buildField(
                    ctl: _displayNameController,
                    label: loc.translate('first_name') ?? 'Ime',
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : 'Unesite ime',
                  ),
                  _buildField(
                    ctl: _lastNameController,
                    label: loc.translate('last_name') ?? 'Prezime',
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : 'Unesite prezime',
                  ),
                  _buildDropdown<String>(
                    value: _country,
                    items: _countryCities.keys.toList(),
                    label: loc.translate('country') ?? 'Država',
                    onChanged: (v) {
                      _country = v!;
                      _isCustomCountry = v == 'Druga država';
                      if (!_isCustomCountry) _customCountryController.clear();
                      setState(() {});
                    },
                  ),
                  if (_isCustomCountry)
                    _buildField(
                      ctl: _customCountryController,
                      label: loc.translate('other_country') ?? 'Unesite državu',
                      validator: (v) =>
                          v != null && v.isNotEmpty ? null : 'Unesite državu',
                    ),
                  _buildDropdown<String>(
                    value: _isCustomCity ? 'Drugi grad' : _city,
                    items: [...?_countryCities[_country], 'Drugi grad'],
                    label: loc.translate('city') ?? 'Grad',
                    onChanged: (v) {
                      if (v == 'Drugi grad') {
                        _isCustomCity = true;
                      } else {
                        _city = v!;
                        _isCustomCity = false;
                      }
                      setState(() {});
                    },
                  ),
                  if (_isCustomCity)
                    _buildField(
                      ctl: _customCityController,
                      label: loc.translate('other_city') ?? 'Unesite grad',
                      validator: (v) =>
                          v != null && v.isNotEmpty ? null : 'Unesite grad',
                    ),
                  _buildField(
                    ctl: _floorController,
                    label: loc.translate('floor') ?? 'Kat',
                  ),
                  _buildField(
                    ctl: _apartmentNumberController,
                    label: loc.translate('apartment_number') ?? 'Broj stana',
                  ),
                  _buildField(
                    ctl: _phoneController,
                    label: loc.translate('phone') ?? 'Broj telefona',
                  ),
                  _buildField(
                    ctl: _addressController,
                    label: loc.translate('address') ?? 'Adresa',
                  ),
                  _buildField(
                    ctl: _ageController,
                    label: loc.translate('age') ?? 'Starost',
                    type: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Unesite starost';
                      final a = int.tryParse(v);
                      if (a == null || a <= 0) return 'Kriva starost';
                      return null;
                    },
                  ),
                  _buildDropdown<String>(
                    value: _selectedEducation,
                    items: _educationLevels,
                    label: loc.translate('education') ?? 'Obrazovanje',
                    onChanged: (v) {
                      _selectedEducation = v!;
                      setState(() {});
                    },
                  ),
                  _buildDropdown<String>(
                    value: _selectedOccupation,
                    items: _occupations,
                    label: loc.translate('occupation') ?? 'Zanimanje',
                    onChanged: (v) {
                      _selectedOccupation = v!;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  // profilna slika
                  Wrap(
                    spacing: 10,
                    children: _predefinedProfileImages.map((p) {
                      final sel = p == _selectedPredefinedImage;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedPredefinedImage = p;
                          _profileImage = null;
                        }),
                        child: Container(
                          decoration: sel
                              ? BoxDecoration(
                                  border:
                                      Border.all(color: Colors.teal, width: 3),
                                  borderRadius: BorderRadius.circular(8))
                              : null,
                          child: Image.asset(p, width: 60, height: 60),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(loc.translate('select_from_gallery') ??
                        'Odaberi profilnu sliku'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _loading ? null : _onFinish,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(loc.translate('finish') ?? 'Završi'),
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
