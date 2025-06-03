import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
// uklonjen import flutter_typeahead
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../utils/utils.dart'; // Importiramo centraliziranu funkciju

/// Zamijenite s vlastitim API ključem
const kGoogleApiKey = "AIzaSyBSjXmxp_LhpuX_hr9AcsKLSIAqWfnNpJM";

class CreateAdScreen extends StatefulWidget {
  final String username;

  /// Početna država i grad (ako ih želite inicijalno prikazati)
  final String countryId;
  final String cityId;

  const CreateAdScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
  });

  @override
  CreateAdScreenState createState() => CreateAdScreenState();
}

class CreateAdScreenState extends State<CreateAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  // Kontroleri za tekstualna polja
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _addressController = TextEditingController();

  // Kontroler za unos grada
  final TextEditingController _cityController = TextEditingController();
  String? _selectedCity;
  String? _selectedCountry;
  String? _selectedCountryCode;

  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;

  // Parametri oglasa
  double _distance = 1.5;
  bool _singleDay = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  // Opcionalno vrijeme početka događaja
  TimeOfDay? _startTime;

  // Za geografiju
  double? _latitude;
  double? _longitude;

  // Identifikator oglasa
  String? _adId;

  // Mapa udaljenost -> cijena
  final Map<double, int> _distancePrices = {1.5: 5, 7.0: 30, 13.0: 150};

  int _numberOfDays = 1;
  double _totalCost = 0.0;
  double _totalDiscount = 0.0;

  // Provjera business korisnika
  String? _businessId;
  bool _isBusinessAccountDeleted = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('hr');

    // Izračun inicijalnog troška
    _computeTotalCost();
    _fetchBusinessInfo();

    // Postavljanje početnih vrijednosti
    if (widget.cityId.isNotEmpty) {
      _cityController.text = widget.cityId;
      _selectedCity = widget.cityId;
      // Normaliziramo naziv države pomoću centralne funkcije
      _selectedCountry = normalizeCountryName(widget.countryId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------------------------------
  // DOHVAĆANJE INFORMACIJA O BUSINESS KORISNIKU
  // ------------------------------------------------------------------------------------------------
  Future<void> _fetchBusinessInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return;
    final userData = userDoc.data();
    if (userData == null) return;

    final fetchedBusinessId = userData['businessId'];
    if (fetchedBusinessId != null && fetchedBusinessId.isNotEmpty) {
      final businessDoc = await FirebaseFirestore.instance
          .collection('business_users')
          .doc(fetchedBusinessId)
          .get();

      if (businessDoc.exists) {
        final businessData = businessDoc.data();
        if (businessData != null) {
          bool deleted = businessData['deleted'] == true;
          setState(() {
            _businessId = fetchedBusinessId;
            _isBusinessAccountDeleted = deleted;
          });
        }
      }
    }
  }

  // ------------------------------------------------------------------------------------------------
  // TYPEAHEAD ZA GRAD - KORIŠTENJE AUTOCOMPLETE WIDGETA
  // ------------------------------------------------------------------------------------------------
  Future<List<Map<String, String>>> fetchCityAndCountry(String input) async {
    // Minimalno 2-3 slova
    if (input.length < 2) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
      'input=${Uri.encodeComponent(input)}'
      '&types=(cities)' // Filtriranje samo gradova
      '&key=$kGoogleApiKey',
    );

    try {
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
            if (detailsData['result'] == null) continue;

            final addressComponents =
                detailsData['result']['address_components'] as List<dynamic>?;
            if (addressComponents == null) continue;

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
        return suggestions;
      }
    } catch (e) {
      _logger.e('fetchCityAndCountry error: $e');
    }
    return [];
  }

  // ------------------------------------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    final dateFormat = DateFormat('dd.MM.yyyy. - EEEE', 'hr');

    // Ako user nije business ili mu je obrisan business račun -> blokiraj
    if (_businessId == null || _isBusinessAccountDeleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizationService.translate('createAd') ?? 'Create Ad'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              localizationService.translate('onlyBusinessCanCreateAd') ??
                  'Samo registrirani poslovni korisnici mogu kreirati oglas.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('createAd') ?? 'Create Ad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Grad - umjesto TypeAheadFormField, koristimo Autocomplete widget
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localizationService.translate('city') ?? 'Grad',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Autocomplete<Map<String, String>>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                        if (textEditingValue.text.length < 2) {
                          return const Iterable<Map<String, String>>.empty();
                        }
                        return await fetchCityAndCountry(textEditingValue.text);
                      },
                      displayStringForOption: (option) => option['city'] ?? '',
                      fieldViewBuilder: (BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted) {
                        // Sinkroniziramo kontroler
                        fieldTextEditingController.text = _cityController.text;
                        return TextFormField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          decoration: InputDecoration(
                            hintText: localizationService
                                .translate('enter_city_name'),
                          ),
                          validator: (value) {
                            if (_selectedCity == null ||
                                _selectedCity!.isEmpty) {
                              return localizationService
                                      .translate('pleaseEnterCity') ??
                                  'Unesite grad';
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

                    // Naziv oglasa
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('title') ?? 'Title',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('pleaseEnterTitle') ??
                              'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Opis
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('description') ??
                                'Description',
                      ),
                      maxLines: 8,
                      maxLength: 1000,
                    ),
                    const SizedBox(height: 20),

                    // Link
                    TextFormField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('link') ?? 'Link',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Adresa
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('address') ??
                            'Address',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('pleaseEnterAddress') ??
                              'Please enter an address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // Gumb za provjeru adrese
                    ElevatedButton(
                      onPressed: _checkAddress,
                      child: Text(
                        localizationService.translate('verifyAddress') ??
                            'Verify Address',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Odabir slike
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text(
                        localizationService.translate('chooseImage') ??
                            'Choose Image',
                      ),
                    ),
                    if (_imageFile != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: kIsWeb
                            ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                            : Image.file(
                                File(_imageFile!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Udaljenost
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localizationService.translate('distance') ??
                            'Distance:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ..._buildDistanceOptions(),

                    const SizedBox(height: 20),

                    // Trajanje (jednodnevni / višednevni)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localizationService.translate('duration') ??
                            'Duration:',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    SwitchListTile(
                      title: Text(localizationService.translate('singleDay') ??
                          'Single Day'),
                      value: _singleDay,
                      onChanged: (value) {
                        setState(() {
                          _singleDay = value;
                          if (_singleDay) {
                            _endDate = null;
                          }
                          _computeTotalCost();
                        });
                      },
                    ),
                    if (_singleDay)
                      ListTile(
                        title: Text(
                          localizationService.translate('selectDate') ??
                              'Select Date',
                        ),
                        subtitle: Text(
                          _startDate != null
                              ? dateFormat.format(_startDate!)
                              : (localizationService
                                      .translate('dateNotSelected') ??
                                  'Date not selected'),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, true),
                      )
                    else
                      Column(
                        children: [
                          ListTile(
                            title: Text(
                              localizationService.translate('startDate') ??
                                  'Start Date',
                            ),
                            subtitle: Text(
                              _startDate != null
                                  ? dateFormat.format(_startDate!)
                                  : (localizationService
                                          .translate('startDateNotSelected') ??
                                      'Start date not selected'),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, true),
                          ),
                          ListTile(
                            title: Text(
                              localizationService.translate('endDate') ??
                                  'End Date',
                            ),
                            subtitle: Text(
                              _endDate != null
                                  ? dateFormat.format(_endDate!)
                                  : (localizationService
                                          .translate('endDateNotSelected') ??
                                      'End date not selected'),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () => _selectDate(context, false),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Unos opcionalnog vremena početka
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        localizationService.translate('startTimeOptional') ??
                            'Start Time (optional)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    ListTile(
                      title: Row(
                        children: [
                          const Icon(Icons.access_time),
                          const SizedBox(width: 8),
                          Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : (localizationService.translate('noTime') ??
                                    'Nije odabrano'),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        localizationService.translate('startTimeNote') ??
                            'Ovaj unos nije obavezan.',
                      ),
                      onTap: () => _selectStartTime(context),
                    ),
                    const SizedBox(height: 20),

                    // Sažetak troškova
                    _buildCostSummary(localizationService, dateFormat),

                    const SizedBox(height: 20),

                    // Gumb za kreiranje oglasa
                    ElevatedButton(
                      onPressed: _onSubmitAd,
                      child: Text(
                        localizationService.translate('createAd') ??
                            'Create Ad',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ------------------------------------------------------------------------------------------------
  // METODA ZA ODABIR VREMENA POČETKA (OPCIONALNO)
  // ------------------------------------------------------------------------------------------------
  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = pickedTime;
      });
    }
  }

  // ------------------------------------------------------------------------------------------------
  // IZGRADNJA WIDGETA ZA ODABIR UDALJENOSTI
  // ------------------------------------------------------------------------------------------------
  List<Widget> _buildDistanceOptions() {
    final widgets = <Widget>[];
    _distancePrices.forEach((dist, price) {
      widgets.add(
        RadioListTile<double>(
          title: Text('$price€ ($dist km)'),
          value: dist,
          groupValue: _distance,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _distance = value;
                _computeTotalCost();
              });
            }
          },
        ),
      );
    });
    return widgets;
  }

  // ------------------------------------------------------------------------------------------------
  // WIDGET - SAŽETAK TROŠKOVA
  // ------------------------------------------------------------------------------------------------
  Widget _buildCostSummary(LocalizationService ls, DateFormat dateFormat) {
    return Card(
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ls.translate('summary') ?? 'Summary',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            Text(
              '${ls.translate('startDate') ?? 'Start Date'}: '
              '${_startDate != null ? dateFormat.format(_startDate!) : '-'}',
            ),
            if (!_singleDay)
              Text(
                '${ls.translate('endDate') ?? 'End Date'}: '
                '${_endDate != null ? dateFormat.format(_endDate!) : '-'}',
              ),
            Text(
              '${ls.translate('numberOfDays') ?? 'Number of Days'}: $_numberOfDays',
            ),
            Text(
              '${ls.translate('distance') ?? 'Distance'}: $_distance km',
            ),
            if (_startTime != null)
              Text(
                '${ls.translate('startTimeOptional') ?? 'Start Time (optional)'}: ${_startTime!.format(context)}',
              ),
            Text(
              '${ls.translate('basePrice') ?? 'Base Price'}: €${(_distancePrices[_distance]! * _numberOfDays).toDouble().toStringAsFixed(2)}',
            ),
            Text(
              '${ls.translate('totalDiscount') ?? 'Total Discount'}: €${_totalDiscount.toStringAsFixed(2)}',
            ),
            Text(
              '${ls.translate('totalPrice') ?? 'Total Price'}: €${_totalCost.toStringAsFixed(2)}',
            ),
            Text(
              ls.translate('currentlyFree') ?? 'Currently Free',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ls.translate('note') ??
                  'Note: Each day after the first reduces the total price by 3%.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------------------------------
  // METODE ZA OBRADU FORMULARA I SPREMANJE OGLASA
  // ------------------------------------------------------------------------------------------------
  void _onSubmitAd() {
    if (!_formKey.currentState!.validate()) return;
    if (!_singleDay && (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select start and end dates'),
        ),
      );
      return;
    }
    _computeTotalCost();
    _showSummaryDialog();
  }

  // Dijalog s potvrdom oglasa
  void _showSummaryDialog() {
    final ls = Provider.of<LocalizationService>(context, listen: false);
    final dateFormat = DateFormat('dd.MM.yyyy.', 'hr');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ls.translate('adSummary') ?? 'Ad Summary'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                    '${ls.translate('title') ?? 'Title'}: ${_titleController.text}'),
                Text(
                    '${ls.translate('description') ?? 'Description'}: ${_descriptionController.text}'),
                Text(
                    '${ls.translate('address') ?? 'Address'}: ${_addressController.text}'),
                Text(
                    '${ls.translate('distance') ?? 'Distance'}: $_distance km ( €${_distancePrices[_distance]} per day)'),
                Text(
                    '${ls.translate('duration') ?? 'Duration'}: ${_singleDay ? (ls.translate('oneDay') ?? 'One day') : '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)} ($_numberOfDays days)'}'),
                if (!_singleDay)
                  Text(
                      '${ls.translate('numberOfDays') ?? 'Number of Days'}: $_numberOfDays'),
                if (_startTime != null)
                  Text(
                      '${ls.translate('startTimeOptional') ?? 'Start Time (optional)'}: ${_startTime!.format(context)}'),
                Text(
                    '${ls.translate('basePrice') ?? 'Base Price'}: €${(_distancePrices[_distance]! * _numberOfDays).toDouble().toStringAsFixed(2)}'),
                Text(
                    '${ls.translate('totalDiscount') ?? 'Total Discount'}: €${_totalDiscount.toStringAsFixed(2)}'),
                Text(
                    '${ls.translate('totalPrice') ?? 'Total Price'}: €${_totalCost.toStringAsFixed(2)}'),
                Text(
                  ls.translate('currentlyFree') ?? 'Currently Free',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  ls.translate('note') ??
                      'Note: Each day after the first reduces the total price by 3%.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ls.translate('cancel') ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _uploadAd();
              },
              child: Text(ls.translate('confirm') ?? 'Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Upload oglasa
  Future<void> _uploadAd() async {
    final ls = Provider.of<LocalizationService>(context, listen: false);

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ls.translate('pleaseVerifyAddress') ??
              'Please verify the address'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ls.translate('userNotLoggedIn') ?? 'User not logged in'),
        ),
      );
      return;
    }

    // Upload slike, ako postoji
    String? imageUrl;
    if (_imageFile != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('ads')
          .child('${user.uid}_${DateTime.now().toIso8601String()}.jpg');
      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await _imageFile!.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        uploadTask = ref.putFile(File(_imageFile!.path));
      }
      await uploadTask;
      imageUrl = await ref.getDownloadURL();
    }
    imageUrl ??= 'https://example.com/default_image.jpg';

    // ID oglasa
    _adId = FirebaseFirestore.instance.collection('ads').doc().id;

    // **Normalizacija države** primijenjena ovdje
    final chosenCountry = normalizeCountryName(
        _selectedCountry ?? _localizeCountryName(widget.countryId));
    final chosenCity = _selectedCity ?? widget.cityId;

    Map<String, dynamic> adData = {
      'id': _adId,
      'title': _titleController.text,
      'description': _descriptionController.text,
      'imageUrl': imageUrl,
      'link': _linkController.text,
      'username': widget.username,
      'userId': user.uid,
      'locationName': chosenCity,
      'coordinates': {
        'lat': _latitude,
        'lng': _longitude,
      },
      'distance': _distance,
      'singleDay': _singleDay,
      'numberOfDays': _numberOfDays,
      'totalCost': _totalCost,
      'address': _addressController.text,
      'createdAt': FieldValue.serverTimestamp(),
      'currentlyFree': true,
      'ended': false,
      'countryId': chosenCountry,
      'startTime': _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : '',
    };

    if (_startDate != null) {
      adData['startDate'] = Timestamp.fromDate(_startDate!);
      if (_singleDay) {
        adData['endDate'] = Timestamp.fromDate(_startDate!);
      }
    }
    if (!_singleDay && _endDate != null) {
      adData['endDate'] = Timestamp.fromDate(_endDate!);
    }

    try {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(chosenCountry)
          .collection('cities')
          .doc(chosenCity)
          .collection('ads')
          .doc(_adId)
          .set(adData);

      await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(user.uid)
          .collection('locations')
          .doc(_adId)
          .set({
        'locationId': _adId,
        'cityId': chosenCity,
        'countryId': chosenCountry,
        'joinedAt': Timestamp.now(),
        'locationName': _titleController.text,
        'deleted': false,
        'locationAdmin': true,
      });

      await FirebaseFirestore.instance
          .collection('location_users')
          .doc(_adId)
          .collection('users')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'joinedAt': Timestamp.now(),
        'deleted': false,
        'displayName': widget.username,
        'email': user.email,
        'role': 'admin',
        'profileImageUrl': 'https://example.com/default_user.png',
      });

      if (_businessId != null && !_isBusinessAccountDeleted) {
        await FirebaseFirestore.instance
            .collection('business_users')
            .doc(_businessId)
            .collection('ads')
            .doc(_adId)
            .set(adData);
      }

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ls.translate('adCreatedSuccessfully') ??
              'Ad created successfully'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _logger.e('Error uploading ad: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ls.translate('errorCreatingAd') ?? 'Error creating ad'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------------------------------------
  // PROVJERA ADRESE (OBAVEZNA)
  // ------------------------------------------------------------------------------------------------
  Future<void> _checkAddress() async {
    final ls = Provider.of<LocalizationService>(context, listen: false);

    if (_addressController.text.isEmpty || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ls.translate('pleaseEnterAddress') ?? 'Please enter an address'),
        ),
      );
      return;
    }

    final fullAddress = '${_addressController.text}, ${_selectedCity!}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?'
      'address=${Uri.encodeComponent(fullAddress)}&key=$kGoogleApiKey&language=hr',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          setState(() {
            _latitude = loc['lat'];
            _longitude = loc['lng'];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ls.translate('addressValidated') ??
                  'Address validated successfully'),
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapConfirmationScreen(
                latitude: _latitude!,
                longitude: _longitude!,
                address: fullAddress,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(ls.translate('addressNotFound') ?? 'Address not found'),
            ),
          );
        }
      } else {
        _logger.e('Error fetching coordinates: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ls.translate('errorFetchingCoordinates') ??
                'Error fetching coordinates'),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ls.translate('errorFetchingCoordinates')} : $e'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------------------------------------
  // DATUMI
  // ------------------------------------------------------------------------------------------------
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final ls = Provider.of<LocalizationService>(context, listen: false);
    DateTime initialDate;
    DateTime firstDate;

    if (isStart) {
      initialDate = _startDate ?? DateTime.now();
      firstDate = DateTime.now();
    } else {
      initialDate = _endDate ??
          (_startDate != null
              ? _startDate!.add(const Duration(days: 1))
              : DateTime.now().add(const Duration(days: 1)));
      firstDate = _startDate != null
          ? _startDate!.add(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 1));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
      locale: const Locale('hr', 'HR'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
        _computeTotalCost();
      });
      if (isStart && !_singleDay) {
        await _selectDate(context, false);
      }
    }
  }

  // ------------------------------------------------------------------------------------------------
  // FUNKCIJE ZA TROŠKOVE
  // ------------------------------------------------------------------------------------------------
  void _computeTotalCost() {
    if (_singleDay) {
      _numberOfDays = 1;
      _totalCost = _distancePrices[_distance]!.toDouble() * 1;
      _totalDiscount = 0.0;
    } else if (_startDate != null && _endDate != null) {
      _numberOfDays = _endDate!.difference(_startDate!).inDays + 1;
      if (_numberOfDays <= 0) {
        _numberOfDays = 0;
        _totalCost = 0.0;
        _totalDiscount = 0.0;
        return;
      }
      double basePrice = _distancePrices[_distance]!.toDouble() * _numberOfDays;
      double totalDiscountRate = (_numberOfDays - 1) * 0.03;
      if (totalDiscountRate > 1.0) totalDiscountRate = 1.0;
      _totalDiscount = basePrice * totalDiscountRate;
      _totalCost = basePrice - _totalDiscount;
    }
  }

  // ------------------------------------------------------------------------------------------------
  // ODABIR SLIKE
  // ------------------------------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
      _logger.i('Image picked: ${pickedFile.path}');
    } else {
      _logger.w('No image selected');
    }
  }

  // ------------------------------------------------------------------------------------------------
  // FUNKCIJA ZA NORMALIZACIJU DRŽAVE (izvorni)
  // ------------------------------------------------------------------------------------------------
  String _localizeCountryName(String countryName) {
    final Map<String, String> mapping = {
      'Croatia': 'Hrvatska',
      'HR': 'Hrvatska',
      'Germany': 'Njemačka',
      // Dodajte ostale prijevode po potrebi
    };
    return mapping[countryName] ?? countryName;
  }
}

// ------------------------------------------------------------------------------------------------
// EKRAN ZA POTVRDU KARTE (INTERAKTIVNA MAPA) BEZ BACK-STRELICE
// ------------------------------------------------------------------------------------------------
class MapConfirmationScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String address;

  const MapConfirmationScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  State<MapConfirmationScreen> createState() => _MapConfirmationScreenState();
}

class _MapConfirmationScreenState extends State<MapConfirmationScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _markers.add(
      Marker(
        markerId: const MarkerId('ad_location'),
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(title: widget.address),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Provjera Adrese',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 15,
            ),
            markers: _markers,
            zoomControlsEnabled: true,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Potvrdi',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
