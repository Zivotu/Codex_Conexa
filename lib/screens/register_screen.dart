// register_screen.dart
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
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';
import 'package:uuid/uuid.dart'; // ← NOVO

import '../services/user_service.dart' as user_service;
import '../services/event_logger.dart';
import '../services/localization_service.dart';
import 'user_locations_screen.dart';
import 'voxpopuli.dart'; // ← trebaš imati već postojići screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  //────────────────── GOOGLE PLACES (REST) ──────────────────
  static const _googleApiKey = 'AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM';
  String _countryCode = 'hr';
  String _countryName = 'Hrvatska';
  String _cityName = 'Zagreb';

  //────────────────── FORM CONTROLLERS ──────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _customCityController = TextEditingController();
  final _customCountryController = TextEditingController();

  //────────────────── STATE VARS ──────────────────
  XFile? _profileImage;
  String? _selectedPredefinedImage;
  String _country = 'Hrvatska';
  String _city = 'Zagreb';
  bool _isLoading = false;
  bool _passwordsMatch = true; // ← za live provjeru lozinki
  final bool _isCustomCity = false;
  final bool _isCustomCountry = false;

  late VideoPlayerController _controller;

  final _auth = FirebaseAuth.instance;
  final _userService = user_service.UserService();
  final _eventLogger = EventLogger();
  final _logger = Logger();

  //────────────────── SELECT DATA ──────────────────
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

  String _selectedEducation = 'SSS - Srednja škola';
  String _selectedOccupation = 'Ostalo';

  final List<String> _predefinedProfileImages = [
    'assets/images/Profile_pic_1.png',
    'assets/images/Profile_pic_2.png',
    'assets/images/Profile_pic_3.png',
    'assets/images/Profile_pic_4.png',
    'assets/images/Profile_pic_5.png',
  ];

  //────────────────── LIFECYCLE ──────────────────
  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.asset('assets/images/register_anim_1.mp4')
          ..initialize().then((_) => setState(() {}));

    // Live provjera lozinki
    _confirmPasswordController.addListener(_checkPasswordMatch);
    _passwordController.addListener(_checkPasswordMatch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _lastNameController.dispose();
    _floorController.dispose();
    _apartmentNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _customCityController.dispose();
    _customCountryController.dispose();
    super.dispose();
  }

  //────────────────── DEVICE-ID ──────────────────
  Future<String> _getOrGenerateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null || id == 'default_device_id') {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  //────────────────── PASSWORD MATCH ──────────────────
  void _checkPasswordMatch() {
    final match = _passwordController.text == _confirmPasswordController.text;
    if (match != _passwordsMatch) {
      setState(() => _passwordsMatch = match);
    }
  }

  //────────────────── UI HELPERS ──────────────────
  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    setState(() {
      _profileImage = img;
      _selectedPredefinedImage = null;
    });
  }

  void _selectPredefinedImage(String p) {
    setState(() {
      _selectedPredefinedImage = p;
      _profileImage = null;
    });
  }

  //─────────────── POP-UP GREŠKA + LOG ───────────────
  Future<void> _showErrorDialog(
      {required String message,
      bool offerReport = true,
      Exception? errorForLog}) async {
    final l = Provider.of<LocalizationService>(context, listen: false);

    if (errorForLog != null) await _logSystemError(errorForLog);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.translate('error') ?? 'Greška'),
        content: Text(message),
        actions: [
          if (offerReport)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VoxPopuliScreen()));
              },
              child: Text(l.translate('report_problem') ?? 'Prijavi problem'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _logSystemError(Exception e) async {
    try {
      final devId = await _getOrGenerateDeviceId();
      await FirebaseFirestore.instance.collection('voxpopuli_hr').add({
        'message': '[SYSTEM_ERROR] ${e.toString()}',
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': devId,
      });
    } catch (_) {
      // ako ni log ne uspije, samo ignoriramo – da ne padne app
    }
  }

  //────────────────── COUNTRY & CITY WIDGETI ──────────────────
  Widget _buildCountryField(LocalizationService l) => TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: l.translate('country') ?? 'Država',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        controller: TextEditingController(text: _countryName),
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: false,
            onSelect: (c) => setState(() {
              _countryName = c.name;
              _countryCode = c.countryCode.toLowerCase();
              _country = _countryName;
              _cityName = '';
              _city = '';
            }),
          );
        },
        validator: (v) => v == null || v.isEmpty
            ? (l.translate('select_country') ?? '')
            : null,
      );

  Future<void> _pickCity() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CitySearchBottomSheet(
          apiKey: _googleApiKey, countryCode: _countryCode),
    );
    if (sel != null) {
      setState(() {
        _cityName = sel;
        _city = sel;
      });
    }
  }

  Widget _buildCityField(LocalizationService l) => TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: l.translate('city') ?? 'Grad',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        controller: TextEditingController(text: _cityName),
        onTap: _pickCity,
        validator: (v) =>
            v == null || v.isEmpty ? (l.translate('select_city') ?? '') : null,
      );

  //────────────────── REGISTRACIJA ──────────────────
  Future<void> _register() async {
    final l = Provider.of<LocalizationService>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      await _showErrorDialog(
          message:
              l.translate('fill_required') ?? 'Popunite sva obavezna polja',
          offerReport: false);
      return;
    }

    if (!_passwordsMatch) {
      await _showErrorDialog(
          message:
              l.translate('passwords_not_match') ?? 'Lozinke se ne podudaraju',
          offerReport: false);
      return;
    }

    setState(() => _isLoading = true);
    _controller.play();
    FocusScope.of(context).unfocus();

    try {
      final appVersion = (await PackageInfo.fromPlatform()).version;
      final devId = await _getOrGenerateDeviceId();

      if (await _userService.isDeviceBlocked(devId)) {
        setState(() => _isLoading = false);
        await _showErrorDialog(
          message: l.translate('device_blocked') ??
              'Ovaj uređaj je blokiran od strane administratora.',
          errorForLog: Exception('Blocked device: $devId'),
        );
        return;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      final user = cred.user;
      if (user == null) throw Exception('FirebaseAuth user == null');

      String? profileImageUrl;
      if (_selectedPredefinedImage != null) {
        profileImageUrl = _selectedPredefinedImage;
      } else if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}.jpg');
        final task = kIsWeb
            ? ref.putData(await _profileImage!.readAsBytes())
            : ref.putFile(File(_profileImage!.path));
        await task;
        profileImageUrl = await ref.getDownloadURL();
      }

      final userData = {
        'userId': user.uid,
        'email': _emailController.text.trim(),
        'displayName': _displayNameController.text,
        'lastName': _lastNameController.text,
        'username': _usernameController.text,
        'floor': _floorController.text,
        'apartmentNumber': _apartmentNumberController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'profileImageUrl': profileImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'countryId':
            _isCustomCountry ? _customCountryController.text.trim() : _country,
        'cityId': _isCustomCity ? _customCityController.text.trim() : _city,
        'balance': 0,
        'locations': [],
        'age': int.tryParse(_ageController.text),
        'education': _selectedEducation,
        'occupation': _selectedOccupation,
        'platform': kIsWeb
            ? 'Web'
            : Platform.isIOS
                ? 'iOS'
                : 'Android',
        'appVersion': appVersion,
        'lastActive': FieldValue.serverTimestamp(),
        'deviceId': devId,
        'blocked': false,
      };

      await _userService.createUserDocument(
        user,
        _country,
        _city,
        '',
        devId,
        additionalData: userData,
      );

      await _eventLogger.logEvent('user_register', {
        'userId': user.uid,
        'countryId': _country,
        'cityId': _city,
        'platform': userData['platform'],
        'appVersion': appVersion,
        'age': userData['age'],
      });

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  UserLocationsScreen(username: _usernameController.text)));
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
          message:
              '${l.translate('registration_failed') ?? 'Registracija nije uspjela'}\n$e',
          errorForLog: Exception(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //────────────────── INPUT HELPER ──────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    VoidCallback? onEditingComplete,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onEditingComplete: onEditingComplete,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      );

  //────────────────── BUILD ──────────────────
  @override
  Widget build(BuildContext context) {
    final l = Provider.of<LocalizationService>(context, listen: false);

    // validator za email
    String? emailValidator(String? v) {
      if (v == null || v.isEmpty) return l.translate('enter_email') ?? '';
      final r = RegExp(r"^[\w.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$");
      return !r.hasMatch(v) ? l.translate('enter_valid_email') ?? '' : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.translate('app_title') ?? 'CONEXA.life'),
        foregroundColor: Colors.black,
        backgroundColor: Colors.grey[200],
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Text(
                    l.translate('register_welcome') ??
                        'Dobrodošli! Registrirajte se',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),

                  //────────── 1) OBAVEZNA POLJA ──────────
                  Card(
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Obavezni podatci',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _buildInputField(
                            controller: _emailController,
                            labelText: l.translate('email') ?? 'Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: emailValidator,
                          ),
                          _buildInputField(
                            controller: _passwordController,
                            labelText: l.translate('password') ?? 'Lozinka',
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return l.translate('enter_password') ?? '';
                              }
                              return v.length < 6
                                  ? l.translate('password_min') ?? ''
                                  : null;
                            },
                          ),
                          _buildInputField(
                            controller: _confirmPasswordController,
                            labelText: l.translate('confirm_password') ??
                                'Potvrda lozinke',
                            obscureText: true,
                            validator: (v) => _passwordsMatch
                                ? null
                                : l.translate('passwords_not_match') ?? '',
                          ),
                          _buildInputField(
                            controller: _usernameController,
                            labelText:
                                l.translate('username') ?? 'Korisničko ime',
                            validator: (v) => (v == null || v.isEmpty)
                                ? l.translate('enter_username') ?? ''
                                : null,
                          ),
                          _buildInputField(
                            controller: _displayNameController,
                            labelText: l.translate('first_name') ?? 'Ime',
                            validator: (v) => (v == null || v.isEmpty)
                                ? l.translate('enter_first_name') ?? ''
                                : null,
                          ),
                          _buildInputField(
                            controller: _lastNameController,
                            labelText: l.translate('last_name') ?? 'Prezime',
                            validator: (v) => (v == null || v.isEmpty)
                                ? l.translate('enter_last_name') ?? ''
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  //────────── 2) DODATNA POLJA ──────────
                  Text('Dodatni podatci (neobavezno)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildInputField(
                      controller: _floorController,
                      labelText: l.translate('floor') ?? 'Kat'),
                  _buildInputField(
                      controller: _apartmentNumberController,
                      labelText:
                          l.translate('apartment_number') ?? 'Broj stana'),
                  _buildInputField(
                      controller: _phoneController,
                      labelText: l.translate('phone') ?? 'Telefon'),
                  _buildInputField(
                      controller: _addressController,
                      labelText: l.translate('address') ?? 'Adresa'),
                  _buildInputField(
                    controller: _ageController,
                    labelText: l.translate('age') ?? 'Starost',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = int.tryParse(v);
                      return (n == null || n <= 0)
                          ? l.translate('enter_valid_age') ?? ''
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: l.translate('education') ?? 'Obrazovanje',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedEducation,
                    items: _educationLevels
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      if (v != null) _selectedEducation = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: l.translate('occupation') ?? 'Zanimanje',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedOccupation,
                    items: _occupations
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      if (v != null) _selectedOccupation = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildCountryField(l),
                  const SizedBox(height: 12),
                  _buildCityField(l),

                  //────────────────── PROFILNA ──────────────────
                  const SizedBox(height: 16),
                  Text(
                    l.translate('profile_image') ?? 'Odaberite profilnu sliku',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _predefinedProfileImages.map((p) {
                      final sel = _selectedPredefinedImage == p;
                      return GestureDetector(
                        onTap: () => _selectPredefinedImage(p),
                        child: Container(
                          decoration: BoxDecoration(
                            border: sel
                                ? Border.all(color: Colors.blueAccent, width: 3)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            p,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: Text(l.translate('select_from_gallery') ??
                        'Odaberite iz galerije'),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedPredefinedImage != null)
                    Image.asset(_selectedPredefinedImage!,
                        width: 100, height: 100)
                  else if (_profileImage != null)
                    kIsWeb
                        ? Image.network(_profileImage!.path,
                            width: 100, height: 100)
                        : Image.file(File(_profileImage!.path),
                            width: 100, height: 100),

                  //────────────────── REGISTER BTN ──────────────────
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                      child: Text(l.translate('register') ?? 'Registriraj se',
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          //────────────────── LOADING OVERLAY ──────────────────
          if (_isLoading)
            Positioned.fill(
              child: Stack(
                children: [
                  _controller.value.isInitialized
                      ? SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        )
                      : Container(color: Colors.black),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

//────────────────── BOTTOM-SHEET ZA GRADOVE ──────────────────
class _CitySearchBottomSheet extends StatefulWidget {
  final String apiKey, countryCode;
  const _CitySearchBottomSheet(
      {required this.apiKey, required this.countryCode});
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
      final cities = (data['predictions'] as List)
          .map((p) => (p['description'] as String).split(',')[0])
          .toList();
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
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: 'Upišite grad',
                    suffixIcon:
                        _loading ? const CircularProgressIndicator() : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
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
