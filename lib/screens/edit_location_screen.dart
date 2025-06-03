import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Zamijenite putanju za vaš vlastiti service ako se razlikuje.
import '../services/localization_service.dart';

class EditLocationScreen extends StatefulWidget {
  final String locationId;
  final String countryId;
  final String cityId;

  const EditLocationScreen({
    super.key,
    required this.locationId,
    required this.countryId,
    required this.cityId,
  });

  @override
  _EditLocationScreenState createState() => _EditLocationScreenState();
}

class _EditLocationScreenState extends State<EditLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  // Obavezna polja:
  String _locationName = '';
  String _locationAddress = '';

  // Ostala (opcionalna) polja:
  int _year = DateTime.now().year;
  File? _selectedImage;
  String? _existingImageUrl;

  String _oib = '';
  String _iban = '';
  String _grad = '';
  String _drzava = '';
  int _brojStanova = 0;
  int _brojLiftova = 0;
  int _godinaIzgradnje = 0;
  int _posljednjaObnovaFasade = 0;
  int _brojKatova = 0;
  String _energetskiCertifikat = '';
  int _brojPoslovnihJedinica = 0;

  // Checkbox polja (opcionalna):
  bool _protupozarniSustav = false;
  bool _alarmniSustav = false;
  bool _videoNadzor = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocationData();
  }

  Future<void> _fetchLocationData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _locationName = data['name'] ?? '';
          _locationAddress = data['address'] ?? '';
          _existingImageUrl = data['imagePath'] ?? '';
          _year = data['year'] ?? DateTime.now().year;

          _oib = data['oib'] ?? '';
          _iban = data['iban'] ?? '';
          _grad = data['grad'] ?? '';
          _drzava = data['drzava'] ?? '';
          _brojStanova = data['brojStanova'] ?? 0;
          _brojLiftova = data['brojLiftova'] ?? 0;
          _godinaIzgradnje = data['godinaIzgradnje'] ?? 0;
          _posljednjaObnovaFasade = data['posljednjaObnovaFasade'] ?? 0;
          _brojKatova = data['brojKatova'] ?? 0;
          _energetskiCertifikat = data['energetskiCertifikat'] ?? '';
          _brojPoslovnihJedinica = data['brojPoslovnihJedinica'] ?? 0;

          _protupozarniSustav = data['protupozarniSustav'] ?? false;
          _alarmniSustav = data['alarmniSustav'] ?? false;
          _videoNadzor = data['videoNadzor'] ?? false;

          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e("Greška prilikom dohvaćanja podataka: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška prilikom dohvaćanja podataka: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        String? imagePath = _existingImageUrl;

        // Ako je korisnik postavio novu sliku, učitaj je u Firebase Storage
        if (_selectedImage != null) {
          imagePath = await _uploadImage(_selectedImage!);
        }

        final updateData = {
          'name': _locationName,
          'address': _locationAddress,
          'year': _year,
          'imagePath': imagePath,
          'oib': _oib,
          'iban': _iban,
          'grad': _grad,
          'drzava': _drzava,
          'brojStanova': _brojStanova,
          'brojLiftova': _brojLiftova,
          'godinaIzgradnje': _godinaIzgradnje,
          'posljednjaObnovaFasade': _posljednjaObnovaFasade,
          'brojKatova': _brojKatova,
          'energetskiCertifikat': _energetskiCertifikat,
          'brojPoslovnihJedinica': _brojPoslovnihJedinica,
          'protupozarniSustav': _protupozarniSustav,
          'alarmniSustav': _alarmniSustav,
          'videoNadzor': _videoNadzor,
        };

        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // 1. Ažuriraj dokument u `/countries/{countryId}/cities/{cityId}/locations/{locationId}`
        final locationRef = firestore
            .collection('countries')
            .doc(widget.countryId)
            .collection('cities')
            .doc(widget.cityId)
            .collection('locations')
            .doc(widget.locationId);
        batch.update(locationRef, updateData);

        // 2. Ažuriraj centralni dokument u `/locations/{locationId}` s istim podacima
        final mainLocationRef =
            firestore.collection('locations').doc(widget.locationId);
        batch.update(mainLocationRef, updateData);

        // 3. Ažuriraj naziv lokacije u svim dokumentima unutar `/user_locations/{userId}/locations/{locationId}`
        final userLocationsSnapshot = await firestore
            .collectionGroup('locations')
            .where('locationId', isEqualTo: widget.locationId)
            .get();

        for (final doc in userLocationsSnapshot.docs) {
          batch.update(doc.reference, {'name': _locationName});
        }

        // 4. Ažuriraj naziv lokacije u `/users/{userId}/owned_locations/{locationId}`
        final ownedLocationsSnapshot = await firestore
            .collectionGroup('owned_locations')
            .where('id', isEqualTo: widget.locationId)
            .get();

        for (final doc in ownedLocationsSnapshot.docs) {
          batch.update(doc.reference, {'name': _locationName});
        }

        // Izvrši batch operacije
        await batch.commit();

        // Obavijest korisnika
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Podaci o lokaciji su uspješno ažurirani.')),
        );

        // Zatvori ekran nakon ažuriranja
        Navigator.pop(context);
      } catch (e) {
        _logger.e("Greška prilikom spremanja podataka: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška prilikom spremanja podataka: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = 'locations/${widget.locationId}.jpg';
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

  Widget _buildLocationImage() {
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      if (_existingImageUrl!.startsWith('assets/')) {
        return Image.asset(
          _existingImageUrl!,
          height: 200,
          fit: BoxFit.cover,
        );
      } else {
        return Image.network(
          _existingImageUrl!,
          height: 200,
          fit: BoxFit.cover,
        );
      }
    } else {
      return const Placeholder(
        fallbackHeight: 200,
        fallbackWidth: double.infinity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('edit_location') ?? 'Uredi lokaciju',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // ============== OBAVEZNA POLJA ==============

                    // Ime lokacije (obavezno)
                    TextFormField(
                      initialValue: _locationName,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('location_name') ??
                                'Ime lokacije',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService.translate(
                                'please_enter_location_name',
                              ) ??
                              'Molimo unesite ime lokacije';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _locationName = value!.trim();
                      },
                    ),

                    // Adresa lokacije (obavezno)
                    TextFormField(
                      initialValue: _locationAddress,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('location_address') ??
                                'Adresa lokacije',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService.translate(
                                'please_enter_location_address',
                              ) ??
                              'Molimo unesite adresu lokacije';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _locationAddress = value!.trim();
                      },
                    ),

                    const SizedBox(height: 20),

                    // ============== OSTALA (OPCIONALNA) POLJA ==============

                    TextFormField(
                      initialValue: _year != 0 ? _year.toString() : '',
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('year') ?? 'Godina',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _year = 0;
                        } else {
                          _year = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    TextFormField(
                      initialValue: _oib,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('oib') ?? 'OIB',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        _oib = value?.trim() ?? '';
                      },
                    ),

                    TextFormField(
                      initialValue: _iban,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('iban') ?? 'IBAN',
                      ),
                      keyboardType: TextInputType.text,
                      onSaved: (value) {
                        _iban = value?.trim() ?? '';
                      },
                    ),

                    TextFormField(
                      initialValue: _grad,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('city') ?? 'Grad',
                      ),
                      onSaved: (value) {
                        _grad = value?.trim() ?? '';
                      },
                    ),

                    TextFormField(
                      initialValue: _drzava,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('country') ??
                            'Država',
                      ),
                      onSaved: (value) {
                        _drzava = value?.trim() ?? '';
                      },
                    ),

                    TextFormField(
                      initialValue:
                          _brojStanova > 0 ? _brojStanova.toString() : '',
                      decoration: InputDecoration(
                        labelText: localizationService
                                .translate('number_of_apartments') ??
                            'Broj stanova',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _brojStanova = 0;
                        } else {
                          _brojStanova = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    TextFormField(
                      initialValue:
                          _brojLiftova > 0 ? _brojLiftova.toString() : '',
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('number_of_lifts') ??
                                'Broj liftova',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _brojLiftova = 0;
                        } else {
                          _brojLiftova = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    TextFormField(
                      initialValue: _godinaIzgradnje > 0
                          ? _godinaIzgradnje.toString()
                          : '',
                      decoration: InputDecoration(
                        labelText: localizationService
                                .translate('year_of_construction') ??
                            'Godina izgradnje',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _godinaIzgradnje = 0;
                        } else {
                          _godinaIzgradnje = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    TextFormField(
                      initialValue: _posljednjaObnovaFasade > 0
                          ? _posljednjaObnovaFasade.toString()
                          : '',
                      decoration: InputDecoration(
                        labelText: localizationService.translate(
                              'last_facade_renovation_year',
                            ) ??
                            'Posljednja obnova fasade (godina)',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _posljednjaObnovaFasade = 0;
                        } else {
                          _posljednjaObnovaFasade = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    TextFormField(
                      initialValue:
                          _brojKatova > 0 ? _brojKatova.toString() : '',
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('number_of_floors') ??
                                'Broj katova',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _brojKatova = 0;
                        } else {
                          _brojKatova = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    DropdownButtonFormField<String>(
                      value: _energetskiCertifikat.isNotEmpty
                          ? _energetskiCertifikat
                          : null,
                      decoration: InputDecoration(
                        labelText: localizationService
                                .translate('energy_certificate') ??
                            'Energetski certifikat',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'A',
                          child:
                              Text(localizationService.translate('A') ?? 'A'),
                        ),
                        DropdownMenuItem(
                          value: 'B',
                          child:
                              Text(localizationService.translate('B') ?? 'B'),
                        ),
                        DropdownMenuItem(
                          value: 'C',
                          child:
                              Text(localizationService.translate('C') ?? 'C'),
                        ),
                        DropdownMenuItem(
                          value: 'D',
                          child:
                              Text(localizationService.translate('D') ?? 'D'),
                        ),
                        DropdownMenuItem(
                          value: 'E',
                          child:
                              Text(localizationService.translate('E') ?? 'E'),
                        ),
                        DropdownMenuItem(
                          value: 'F',
                          child:
                              Text(localizationService.translate('F') ?? 'F'),
                        ),
                        DropdownMenuItem(
                          value: 'G',
                          child:
                              Text(localizationService.translate('G') ?? 'G'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _energetskiCertifikat = value ?? '';
                        });
                      },
                      onSaved: (value) {
                        _energetskiCertifikat = value ?? '';
                      },
                    ),

                    TextFormField(
                      initialValue: _brojPoslovnihJedinica > 0
                          ? _brojPoslovnihJedinica.toString()
                          : '',
                      decoration: InputDecoration(
                        labelText: localizationService
                                .translate('number_of_business_units') ??
                            'Broj poslovnih jedinica',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) {
                        if (value == null || value.isEmpty) {
                          _brojPoslovnihJedinica = 0;
                        } else {
                          _brojPoslovnihJedinica = int.tryParse(value) ?? 0;
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // ============== CHECKBOX POLJA (OPCIONALNA) ==============
                    CheckboxListTile(
                      title: Text(
                        localizationService
                                .translate('fire_protection_system') ??
                            'Protupožarni sustav',
                      ),
                      value: _protupozarniSustav,
                      onChanged: (bool? value) {
                        setState(() {
                          _protupozarniSustav = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        localizationService.translate('alarm_system') ??
                            'Alarmni sustav',
                      ),
                      value: _alarmniSustav,
                      onChanged: (bool? value) {
                        setState(() {
                          _alarmniSustav = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        localizationService.translate('video_surveillance') ??
                            'Video nadzor',
                      ),
                      value: _videoNadzor,
                      onChanged: (bool? value) {
                        setState(() {
                          _videoNadzor = value ?? false;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // ============== DIO ZA SLIKU (OPCIONALNA) ==============
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text(
                        localizationService
                                .translate('change_location_image') ??
                            'Izmijeni sliku lokacije',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLocationImage(),
                    const SizedBox(height: 20),

                    // ============== GUMB ZA SPREMANJE ==============
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text(
                        localizationService.translate('save_changes') ??
                            'Spremi promjene',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
