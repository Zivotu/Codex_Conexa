// lib/screens/affiliate_register_screen.dart

import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/affiliate_code.dart';

// za REST pozive i country picker
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';

import '../services/user_service.dart' as user_service;
import '../services/event_logger.dart';
import '../services/localization_service.dart';
import 'user_locations_screen.dart';

class AffiliateRegisterScreen extends StatefulWidget {
  final String? userId;
  const AffiliateRegisterScreen({super.key, this.userId});

  @override
  _AffiliateRegisterScreenState createState() =>
      _AffiliateRegisterScreenState();
}

class _AffiliateRegisterScreenState extends State<AffiliateRegisterScreen> {
  //────────── Google Places REST ──────────
  static const _googleApiKey = 'AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM';
  String _countryCode = 'hr';
  String _countryName = 'Hrvatska';
  String _cityName = 'Zagreb';

  //────────── UI + poslovna logika ──────────
  final _formKey = GlobalKey<FormState>();
  final _log = Logger();
  final _auth = FirebaseAuth.instance;
  final _userService = user_service.UserService();
  final _eventLogger = EventLogger();

  // kontroleri
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _usernameC = TextEditingController();
  final _firstNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _floorC = TextEditingController();
  final _apartmentC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _ageC = TextEditingController();
  final _customCountryC = TextEditingController();
  final _customCityC = TextEditingController();

  XFile? _profileImage;
  String? _selectedPreset;
  bool _isCustomCountry = false;
  bool _isCustomCity = false;

  String _education = 'SSS - Srednja škola';
  String _occupation = 'Ostalo';

  late VideoPlayerController _videoCtrl;
  bool _loading = false;

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
  final List<String> _presetImages = [
    'assets/images/Profile_pic_1.png',
    'assets/images/Profile_pic_2.png',
    'assets/images/Profile_pic_3.png',
    'assets/images/Profile_pic_4.png',
    'assets/images/Profile_pic_5.png',
  ];

  bool get _isExisting => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _videoCtrl =
        VideoPlayerController.asset('assets/images/register_anim_1.mp4')
          ..initialize().then((_) => setState(() {}));
    if (_isExisting) _loadUserData();
  }

  Future<void> _loadUserData() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final data = snap.data();
    if (data == null) return;
    // popuni kontrolere
    _emailC.text = data['email'] ?? '';
    _usernameC.text = data['username'] ?? '';
    _firstNameC.text = data['displayName'] ?? '';
    _lastNameC.text = data['lastName'] ?? '';
    _floorC.text = data['floor'] ?? '';
    _apartmentC.text = data['apartmentNumber'] ?? '';
    _phoneC.text = data['phone'] ?? '';
    _addressC.text = data['address'] ?? '';
    _ageC.text = (data['age']?.toString() ?? '');
    // država/grad
    _countryName = data['countryId'] ?? _countryName;
    _countryCode = 'hr'; // ili mapiraj iz baze
    _cityName = data['cityId'] ?? _cityName;
    _education = data['education'] ?? _education;
    _occupation = data['occupation'] ?? _occupation;
    // preset slika
    final url = data['profileImageUrl'];
    if (url is String && _presetImages.contains(url)) {
      _selectedPreset = url;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _usernameC.dispose();
    _firstNameC.dispose();
    _lastNameC.dispose();
    _floorC.dispose();
    _apartmentC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _ageC.dispose();
    _customCountryC.dispose();
    _customCityC.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) {
      setState(() {
        _profileImage = f;
        _selectedPreset = null;
      });
    }
  }

  Future<String?> _getDeviceId() async =>
      (await SharedPreferences.getInstance()).getString('device_id') ??
      'unknown';

  //────── Country Picker field ──────
  Widget _buildCountryField(LocalizationService l) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: _countryName),
      decoration: InputDecoration(
        labelText: l.translate('country') ?? 'Država',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: false,
          onSelect: (c) => setState(() {
            _countryName = c.name;
            _countryCode = c.countryCode.toLowerCase();
            _isCustomCountry = false;
          }),
        );
      },
      validator: (v) => (v == null || v.isEmpty)
          ? l.translate('select_country') ?? 'Odaberite državu'
          : null,
    );
  }

  //────── City autocomplete ──────
  Future<void> _pickCity() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CitySearchBottomSheet(
        apiKey: _googleApiKey,
        countryCode: _countryCode,
      ),
    );
    if (sel != null) {
      setState(() {
        _cityName = sel;
        _isCustomCity = false;
      });
    }
  }

  Widget _buildCityField(LocalizationService l) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: _cityName),
      decoration: InputDecoration(
        labelText: l.translate('city') ?? 'Grad',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: _pickCity,
      validator: (v) => (v == null || v.isEmpty)
          ? l.translate('select_city') ?? 'Odaberite grad'
          : null,
    );
  }

  Widget _field({
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _dropdown<T>({
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

  Future<void> _submit() async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _videoCtrl.play();
    FocusScope.of(context).unfocus();

    try {
      // 1) Auth (najjbolje da se provjera lozinke već odvila)
      User? user;
      if (!_isExisting) {
        if (_passwordC.text != _confirmC.text) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.translate('passwords_not_match') ??
                'Lozinke se ne podudaraju'),
          ));
          setState(() => _loading = false);
          return;
        }
        final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailC.text.trim(),
          password: _passwordC.text,
        );
        user = cred.user!;
      } else {
        user = _auth.currentUser;
      }
      if (user == null) throw 'Korisnik nije dostupan';

      // 2) upload slike
      String? profileUrl;
      if (_profileImage != null) {
        final ref =
            FirebaseStorage.instance.ref().child('user_images/${user.uid}.jpg');
        final task = kIsWeb
            ? ref.putData(await _profileImage!.readAsBytes())
            : ref.putFile(File(_profileImage!.path));
        await task;
        profileUrl = await ref.getDownloadURL();
      } else if (_selectedPreset != null) {
        profileUrl = _selectedPreset;
      }

      // 3) spremi ili ažuriraj user doc
      final pkg = await PackageInfo.fromPlatform();
      final devId = await _getDeviceId();
      final data = {
        'email': _emailC.text.trim(),
        'username': _usernameC.text.trim(),
        'displayName': _firstNameC.text.trim(),
        'lastName': _lastNameC.text.trim(),
        'floor': _floorC.text.trim(),
        'apartmentNumber': _apartmentC.text.trim(),
        'phone': _phoneC.text.trim(),
        'address': _addressC.text.trim(),
        'age': int.tryParse(_ageC.text),
        'countryId':
            _isCustomCountry ? _customCountryC.text.trim() : _countryName,
        'cityId': _isCustomCity ? _customCityC.text.trim() : _cityName,
        'education': _education,
        'occupation': _occupation,
        'profileImageUrl': profileUrl,
        'appVersion': pkg.version,
        'deviceId': devId,
        'affiliateActive': true,
      };

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (_isExisting) {
        await ref.update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.set(data);
      }

      await _eventLogger
          .logEvent(_isExisting ? 'user_become_affiliate' : 'user_register', {
        'userId': user.uid,
      });

      // 4) affiliate kod
      final code = generateAffiliateCode(
        _firstNameC.text.trim(),
        _lastNameC.text.trim(),
      );
      await FirebaseFirestore.instance.collection('affiliate_bonus_codes').add({
        'active': false,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'partnerEmail': user.email,
        'partnerFirstName': _firstNameC.text.trim(),
        'partnerLastName': _lastNameC.text.trim(),
        'redeemedBy': <String>[],
        'redemptions': 0,
        'userId': user.uid,
      });

      // 5) ista poruka za oba slučaja
      if (!mounted) return;
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
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => UserLocationsScreen(
                      username: _usernameC.text.trim(),
                    ),
                  ),
                );
              },
              child: Text(loc.translate('ok') ?? 'OK'),
            )
          ],
        ),
      );
    } catch (e) {
      _log.e('Affiliate registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
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
        title: Text(loc.translate('affiliate_register') ??
            (_isExisting ? 'Dopuni podatke' : 'Registracija partnera')),
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
                  // za nove: email + pass
                  if (!_isExisting) ...[
                    _field(
                      ctl: _emailC,
                      label: loc.translate('email') ?? 'Email',
                      type: TextInputType.emailAddress,
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Neispravan email',
                    ),
                    _field(
                      ctl: _passwordC,
                      label: loc.translate('password') ?? 'Lozinka',
                      obscure: true,
                      validator: (v) => v != null && v.length >= 6
                          ? null
                          : 'Lozinka min. 6 znakova',
                    ),
                    _field(
                      ctl: _confirmC,
                      label: loc.translate('confirm_password') ??
                          'Potvrdi lozinku',
                      obscure: true,
                      validator: (v) => v == _passwordC.text
                          ? null
                          : 'Lozinke se ne podudaraju',
                    ),
                  ] else
                    _field(
                      ctl: _emailC,
                      label: loc.translate('email') ?? 'Email',
                      readOnly: true,
                    ),

                  _field(
                    ctl: _usernameC,
                    label: loc.translate('username') ?? 'Korisničko ime',
                    validator: (v) => v != null && v.isNotEmpty
                        ? null
                        : 'Unesite korisničko ime',
                  ),
                  _field(
                    ctl: _firstNameC,
                    label: loc.translate('first_name') ?? 'Ime',
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : 'Unesite ime',
                  ),
                  _field(
                    ctl: _lastNameC,
                    label: loc.translate('last_name') ?? 'Prezime',
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : 'Unesite prezime',
                  ),

                  const SizedBox(height: 16),
                  _buildCountryField(loc),
                  const SizedBox(height: 16),
                  _buildCityField(loc),
                  const SizedBox(height: 16),

                  _field(ctl: _floorC, label: loc.translate('floor') ?? 'Kat'),
                  _field(
                      ctl: _apartmentC,
                      label: loc.translate('apartment_number') ?? 'Broj stana'),
                  _field(
                      ctl: _phoneC,
                      label: loc.translate('phone') ?? 'Broj telefona'),
                  _field(
                      ctl: _addressC,
                      label: loc.translate('address') ?? 'Adresa'),
                  _field(
                    ctl: _ageC,
                    label: loc.translate('age') ?? 'Starost',
                    type: TextInputType.number,
                    validator: (v) {
                      final a = int.tryParse(v ?? '');
                      return (a != null && a > 0) ? null : 'Neispravna starost';
                    },
                  ),

                  const SizedBox(height: 16),
                  _dropdown<String>(
                    value: _education,
                    items: _educationLevels,
                    label: loc.translate('education') ?? 'Obrazovanje',
                    onChanged: (v) => setState(() => _education = v!),
                  ),
                  const SizedBox(height: 16),
                  _dropdown<String>(
                    value: _occupation,
                    items: _occupations,
                    label: loc.translate('occupation') ?? 'Zanimanje',
                    onChanged: (v) => setState(() => _occupation = v!),
                  ),

                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    children: _presetImages.map((p) {
                      final sel = p == _selectedPreset;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedPreset = p;
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
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isExisting
                                ? (loc.translate('finish') ?? 'Završi')
                                : (loc.translate('register') ??
                                    'Registriraj se'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading && _videoCtrl.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

//─── Bottom‑sheet za gradove ───

class _CitySearchBottomSheet extends StatefulWidget {
  final String apiKey, countryCode;
  const _CitySearchBottomSheet({
    required this.apiKey,
    required this.countryCode,
  });
  @override
  _CitySearchBottomSheetState createState() => _CitySearchBottomSheetState();
}

class _CitySearchBottomSheetState extends State<_CitySearchBottomSheet> {
  final _ctrl = TextEditingController();
  List<String> _suggestions = [];
  bool _loading = false;

  Future<void> _fetch(String input) async {
    if (input.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'types': '(cities)',
          'components': 'country:${widget.countryCode}',
          'key': widget.apiKey,
        },
      );
      final res = await http.get(uri);
      final data = json.decode(res.body);
      final cities = (data['predictions'] as List).map((p) {
        final desc = (p['description'] as String);
        return desc.split(',')[0];
      }).toList();
      setState(() => _suggestions = cities.cast<String>());
    } catch (_) {
      setState(() => _suggestions = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Upišite grad',
                    suffixIcon:
                        _loading ? const CircularProgressIndicator() : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _fetch,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(_suggestions[i]),
                    onTap: () => Navigator.of(context).pop(_suggestions[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
