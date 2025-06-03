import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' if (kIsWeb) 'dart:html';
import 'package:uuid/uuid.dart';
import 'post_registration_screen.dart';
import '../utils/activity_codes.dart'; // Import ActivityCodes
import 'package:firebase_messaging/firebase_messaging.dart'; // Dodano
import 'package:logger/logger.dart';
import '../services/localization_service.dart'; // ✅ OVO DODANO

class NewServicerRegistrationScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const NewServicerRegistrationScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  NewServicerRegistrationScreenState createState() =>
      NewServicerRegistrationScreenState();
}

class NewServicerRegistrationScreenState
    extends State<NewServicerRegistrationScreen> {
  // Definicija Logger unutar klase
  final Logger _logger = Logger();

  final _formKey = GlobalKey<FormState>();

  // Kontroleri za osobne podatke
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _personalIdController =
      TextEditingController(); // OIB
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Kontroleri za podatke o tvrtki
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyPhoneController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _companyOibController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();
  final TextEditingController _companyMaticniBrojController =
      TextEditingController();
  final TextEditingController _nkdController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  // Kontroleri za dodatnu dokumentaciju
  XFile? _selectedPersonalIdDocument;
  XFile? _selectedAdditionalDocument;
  XFile? _selectedWorkshopPhoto;
  XFile? _selectedProfileImage;

  // Dropdown za državu i grad tvrtke
  String? _companySelectedCountry;
  String? _companySelectedCity;
  String? _companyOtherCountry;
  String? _companyOtherCity;

  // Dropdown za radnu državu i grad
  String? _workingSelectedCountry;
  String? _workingSelectedCity;
  String? _workingOtherCountry;
  String? _workingOtherCity;

  // ImagePicker
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

// Lista djelatnosti (NKD) - puni se nakon initState
  List<Map<String, String>> _serviceTypes = [];

  void _loadServiceTypes() {
    final localized = LocalizationService.instance;
    setState(() {
      _serviceTypes = ActivityCodes.getAllCategories(localized);
    });
  }

  // Lista europskih država
  final List<String> _countries = [
    'Albanija',
    'Andora',
    'Austrija',
    'Belgija',
    'Bosna i Hercegovina',
    'Bugarska',
    'Češka',
    'Danska',
    'Estonija',
    'Finska',
    'Francuska',
    'Hrvatska',
    'Njemačka',
    'Grčka',
    'Mađarska',
    'Island',
    'Irska',
    'Italija',
    'Latvija',
    'Liechtenstein',
    'Litva',
    'Luxemburg',
    'Malta',
    'Monako',
    'Crna Gora',
    'Nizozemska',
    'Norveška',
    'Poljska',
    'Portugal',
    'Rumunjska',
    'San Marino',
    'Slovačka',
    'Slovenija',
    'Španjolska',
    'Švedska',
    'Švicarska',
    'Ujedinjeno Kraljevstvo',
    'Ukrajina',
    'Ostalo',
  ];

  // Lista gradova
  final Map<String, List<String>> _citiesByCountry = {
    'Hrvatska': ['Zagreb', 'Split', 'Rijeka', 'Osijek', 'Ostalo'],
    'Njemačka': ['Berlin', 'Munchen', 'Hamburg', 'Ostalo'],
    'Austrija': ['Beč', 'Graz', 'Linz', 'Ostalo'],
    // Dodajte ostale zemlje i gradove po potrebi
  };

  // Lista za odabrane licence
  final List<String> _selectedLicenses = [];

  @override
  void initState() {
    super.initState();

    // FCM listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _saveServicerFcmToken(currentUser.uid);
      }
    });

    // Učitaj kategorije kada je sve spremno
    _loadServiceTypes();
  }

  @override
  void dispose() {
    // Oslobađanje kontrolera
    _firstNameController.dispose();
    _lastNameController.dispose();
    _personalIdController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyOibController.dispose();
    _companyAddressController.dispose();
    _companyMaticniBrojController.dispose();
    _nkdController.dispose();
    _ownerController.dispose();
    _websiteController.dispose();

    super.dispose();
  }

  // Metoda za upload datoteka u Firebase Storage
  Future<String> _uploadFile(XFile file, String folder) async {
    const uuid = Uuid();
    final fileName = '${uuid.v4()}.${file.name.split('.').last}';
    final ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes);
    } else {
      await ref.putFile(File(file.path));
    }

    return await ref.getDownloadURL();
  }

  // Metode za odabir slika/dokumenata
  Future<void> _pickPersonalIdDocument() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedPersonalIdDocument = picked;
      });
    }
  }

  Future<void> _pickAdditionalDocument() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedAdditionalDocument = picked;
      });
    }
  }

  Future<void> _pickWorkshopPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedWorkshopPhoto = picked;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedProfileImage = picked;
      });
    }
  }

  // Dodana metoda za spremanje FCM tokena
  Future<void> _saveServicerFcmToken(String servicerId) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      // Ažuriraj FCM token u 'servicers' kolekciji
      await FirebaseFirestore.instance
          .collection('servicers')
          .doc(servicerId)
          .update({
        'fcmToken': fcmToken,
      });

      // Ažuriraj FCM token u 'users' kolekciji
      await FirebaseFirestore.instance
          .collection('users')
          .doc(servicerId)
          .update({
        'fcmToken': fcmToken,
      });

      _logger.d("FCM token saved successfully for user $servicerId");
    } catch (e) {
      _logger.e("Error saving FCM token for $servicerId: $e");
    }
  }

  Future<void> _registerServicer() async {
    if (_formKey.currentState!.validate()) {
      // Provjera odabira države i grada za tvrtku
      if (_companySelectedCountry == null ||
          (_companySelectedCity == null && _companyOtherCity == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Molimo odaberite državu i grad tvrtke')),
        );
        return;
      }

      // Provjera odabira radne lokacije
      if (_workingSelectedCountry == null ||
          (_workingSelectedCity == null && _workingOtherCity == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Molimo odaberite radnu državu i grad')),
        );
        return;
      }

      // Provjera odabira licenci
      if (_selectedLicenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Molimo odaberite barem jednu licencu')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Provjera za "Ostalo" za tvrtku
        final companyCountryToSave =
            _companySelectedCountry == 'Ostalo' && _companyOtherCountry != null
                ? _companyOtherCountry!
                : _companySelectedCountry!;

        final companyCityToSave =
            _companySelectedCity == 'Ostalo' && _companyOtherCity != null
                ? _companyOtherCity!
                : _companySelectedCity!;

        // Provjera za "Ostalo" za radnu lokaciju
        final workingCountryToSave =
            _workingSelectedCountry == 'Ostalo' && _workingOtherCountry != null
                ? _workingOtherCountry!
                : _workingSelectedCountry!;

        final workingCityToSave =
            _workingSelectedCity == 'Ostalo' && _workingOtherCity != null
                ? _workingOtherCity!
                : _workingSelectedCity!;

        // Upload profilne slike
        String? profileImageUrl;
        if (_selectedProfileImage != null) {
          profileImageUrl = await _uploadFile(
            _selectedProfileImage!,
            'servicer_profile_images',
          );
        }

        // Upload dokumenta osobne iskaznice
        String? personalIdUrl;
        if (_selectedPersonalIdDocument != null) {
          personalIdUrl = await _uploadFile(
            _selectedPersonalIdDocument!,
            'personal_id_documents',
          );
        }

        // Upload dodatne dokumentacije
        String? additionalDocumentUrl;
        if (_selectedAdditionalDocument != null) {
          additionalDocumentUrl = await _uploadFile(
            _selectedAdditionalDocument!,
            'additional_documents',
          );
        }

        // Upload fotografije radione
        String? workshopPhotoUrl;
        if (_selectedWorkshopPhoto != null) {
          workshopPhotoUrl = await _uploadFile(
            _selectedWorkshopPhoto!,
            'workshop_photos',
          );
        }

        // Registracija korisnika ako nije prijavljen
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          UserCredential userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password:
                'default_password', // Promijenite prema potrebama ili dodajte polje za unos lozinke
          );
          currentUser = userCredential.user;
        }

        // Priprema podataka za Firestore
        final servicerData = {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'personalId': _personalIdController.text.trim(),
          'phone': _phoneController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'email': _emailController.text.trim(),
          'companyName': _companyNameController.text.trim(),
          'companyPhone': _companyPhoneController.text.trim(),
          'companyEmail': _companyEmailController.text.trim(),
          'companyOib': _companyOibController.text.trim(),
          'companyAddress': _companyAddressController.text.trim(),
          'companyMaticniBroj': _companyMaticniBrojController.text.trim(),
          'nkd': _nkdController.text.trim(),
          'owner': _ownerController.text.trim(),
          'website': _websiteController.text.trim(),
          'selectedCategories': _selectedLicenses,
          'profileImageUrl': profileImageUrl ?? '',
          'personalIdUrl': personalIdUrl ?? '',
          'additionalDocumentUrl': additionalDocumentUrl ?? '',
          'workshopPhotoUrl': workshopPhotoUrl ?? '',
          'userId': currentUser!.uid,
          'servicerId': currentUser.uid, // Koristite userId kao servicerId
          'companyCountry': companyCountryToSave,
          'companyCity': companyCityToSave,
          'workingCountry': workingCountryToSave,
          'workingCity': workingCityToSave,
          'createdAt': FieldValue.serverTimestamp(),
          'username': widget.username,
          // Uklonjeno countryId, cityId, locationId
        };

        // Pohrana podataka u centraliziranu kolekciju 'servicers'
        await FirebaseFirestore.instance
            .collection('servicers')
            .doc(currentUser.uid)
            .set(servicerData);

        // Pohrana osnovnih podataka u 'users' kolekciju
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

        final userData = {
          'userId': currentUser.uid,
          'email': _emailController.text.trim(),
          'companyName': _companyNameController.text.trim(),
          'address': _companyAddressController.text.trim(),
          'phone': _companyPhoneController.text.trim(),
          'userType': 'servicer',
          'servicerId': currentUser.uid, // Dodano servicerId
          'serviceType': _selectedLicenses, // Spremanje lista licenci
          'companyCountry': companyCountryToSave,
          'companyCity': companyCityToSave,
          'workingCountry': workingCountryToSave,
          'workingCity': workingCityToSave,
          'username': widget.username,
          // Uklonjeno countryId, cityId, locationId
        };

        await userRef.set(userData, SetOptions(merge: true));

        // Dobivanje i spremanje FCM tokena
        await _saveServicerFcmToken(currentUser.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Serviser uspješno registriran')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PostRegistrationScreen(),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška prilikom registracije: $e')),
        );
        _logger.e("Error during servicer registration: $e"); // Dodan logger
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registracija servisera',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Osobni podaci
                const Text(
                  "Osobni podaci",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Ime'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite ime' : null,
                ),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Prezime'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite prezime' : null,
                ),
                TextFormField(
                  controller: _personalIdController,
                  decoration: const InputDecoration(labelText: 'OIB'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite OIB' : null,
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite telefon' : null,
                ),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(labelText: 'Mobitel'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite mobitel' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite email' : null,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Priložite presliku osobne iskaznice s obje strane za sigurnost korisnika. '
                  'Podaci se koriste isključivo za potvrdu identiteta i sprječavanje prevara.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                ElevatedButton.icon(
                  onPressed: _pickPersonalIdDocument,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Priložite osobnu iskaznicu'),
                ),
                if (_selectedPersonalIdDocument != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: kIsWeb
                        ? Image.network(
                            _selectedPersonalIdDocument!.path,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedPersonalIdDocument!.path),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),
                const Divider(height: 30, thickness: 2),

                // Podaci o tvrtki
                const Text(
                  "Podaci o tvrtki",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Naziv tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite naziv tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _companyPhoneController,
                  decoration:
                      const InputDecoration(labelText: 'Telefon tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite telefon tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _companyEmailController,
                  decoration: const InputDecoration(labelText: 'Email tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite email tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _companyOibController,
                  decoration: const InputDecoration(labelText: 'OIB tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite OIB tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _companyAddressController,
                  decoration: const InputDecoration(labelText: 'Adresa tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite adresu tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _companyMaticniBrojController,
                  decoration:
                      const InputDecoration(labelText: 'Matični broj tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite matični broj tvrtke'
                      : null,
                ),
                TextFormField(
                  controller: _nkdController,
                  decoration:
                      const InputDecoration(labelText: 'Djelatnost (NKD)'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite NKD' : null,
                ),
                TextFormField(
                  controller: _ownerController,
                  decoration: const InputDecoration(
                      labelText: 'Vlasnik/odgovorna osoba'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite vlasnika/odgovornu osobu'
                      : null,
                ),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(labelText: 'Web stranica'),
                ),

                const Divider(height: 30, thickness: 2),

                // Odabir kategorija
                const Text(
                  "Odabir kategorija (licenci)",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ..._serviceTypes.map((type) {
                  return CheckboxListTile(
                    title: Text(type['name']!),
                    value: _selectedLicenses.contains(type['type']),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedLicenses.add(type['type']!);
                        } else {
                          _selectedLicenses.remove(type['type']!);
                        }
                      });
                    },
                  );
                }),

                const Divider(height: 30, thickness: 2),

                // Lokacija tvrtke
                const Text(
                  "Lokacija tvrtke",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Država tvrtke'),
                  items: _countries.map((country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _companySelectedCountry = value;
                      _companySelectedCity = null;
                      _companyOtherCountry = null;
                      _companyOtherCity = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Odaberite državu tvrtke' : null,
                ),
                if (_companySelectedCountry == 'Ostalo')
                  TextFormField(
                    decoration: const InputDecoration(
                        labelText: 'Unesite državu tvrtke'),
                    onChanged: (value) {
                      _companyOtherCountry = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Unesite državu tvrtke'
                        : null,
                  ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Grad tvrtke'),
                  items: _companySelectedCountry != null &&
                          _citiesByCountry.containsKey(_companySelectedCountry)
                      ? _citiesByCountry[_companySelectedCountry]!.map((city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList()
                      : [],
                  onChanged: (value) {
                    setState(() {
                      _companySelectedCity = value;
                      _companyOtherCity = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Odaberite grad tvrtke' : null,
                ),
                if (_companySelectedCity == 'Ostalo')
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Unesite grad tvrtke'),
                    onChanged: (value) {
                      _companyOtherCity = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Unesite grad tvrtke'
                        : null,
                  ),

                const Divider(height: 30, thickness: 2),

                // Područje rada
                const Text(
                  "Područje rada",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Država rada'),
                  items: _countries.map((country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _workingSelectedCountry = value;
                      _workingSelectedCity = null;
                      _workingOtherCountry = null;
                      _workingOtherCity = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Odaberite državu rada' : null,
                ),
                if (_workingSelectedCountry == 'Ostalo')
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Unesite državu rada'),
                    onChanged: (value) {
                      _workingOtherCountry = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Unesite državu rada'
                        : null,
                  ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Grad rada'),
                  items: _workingSelectedCountry != null &&
                          _citiesByCountry.containsKey(_workingSelectedCountry)
                      ? _citiesByCountry[_workingSelectedCountry]!.map((city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList()
                      : [],
                  onChanged: (value) {
                    setState(() {
                      _workingSelectedCity = value;
                      _workingOtherCity = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Odaberite grad rada' : null,
                ),
                if (_workingSelectedCity == 'Ostalo')
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Unesite grad rada'),
                    onChanged: (value) {
                      _workingOtherCity = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Unesite grad rada'
                        : null,
                  ),

                const Divider(height: 30, thickness: 2),

                // Dodatna dokumentacija
                const Text(
                  "Dodatna dokumentacija",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAdditionalDocument,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Priložite dodatnu dokumentaciju'),
                ),
                if (_selectedAdditionalDocument != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: kIsWeb
                        ? Image.network(
                            _selectedAdditionalDocument!.path,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedAdditionalDocument!.path),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),
                ElevatedButton.icon(
                  onPressed: _pickWorkshopPhoto,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Priložite fotografiju radione'),
                ),
                if (_selectedWorkshopPhoto != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: kIsWeb
                        ? Image.network(
                            _selectedWorkshopPhoto!.path,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedWorkshopPhoto!.path),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),

                const Divider(height: 30, thickness: 2),

                // Profilna fotografija
                const Text(
                  "Profilna fotografija",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _pickProfileImage,
                  icon: const Icon(Icons.person),
                  label: const Text('Priložite profilnu fotografiju'),
                ),
                if (_selectedProfileImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: kIsWeb
                        ? Image.network(
                            _selectedProfileImage!.path,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedProfileImage!.path),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),

                const Divider(height: 30, thickness: 2),

                // Registracija gumb
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _registerServicer,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Registriraj se',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
