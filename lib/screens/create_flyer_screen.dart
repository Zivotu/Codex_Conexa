// lib/screens/create_flyer_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/utils.dart'; // Import centralizirane funkcije
import '../services/localization_service.dart';

class CreateFlyerScreen extends StatefulWidget {
  const CreateFlyerScreen({super.key});

  @override
  _CreateFlyerScreenState createState() => _CreateFlyerScreenState();
}

class _CreateFlyerScreenState extends State<CreateFlyerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _oibController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedPdf;
  File? _selectedImage;
  bool _isUploading = false;
  bool _showInAllCities = false;

  final picker = ImagePicker();

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      setState(() {
        _selectedPdf = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadFlyer() async {
    if (_formKey.currentState!.validate() &&
        _selectedPdf != null &&
        _selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        final pdfStorageRef = FirebaseStorage.instance
            .ref()
            .child('flyers/${_selectedPdf!.path.split('/').last}');
        final imageStorageRef = FirebaseStorage.instance
            .ref()
            .child('flyer_images/${_selectedImage!.path.split('/').last}');

        // Upload PDF
        final pdfUploadTask = pdfStorageRef.putFile(_selectedPdf!);
        final pdfUrl = await (await pdfUploadTask).ref.getDownloadURL();

        // Upload Image
        final imageUploadTask = imageStorageRef.putFile(_selectedImage!);
        final imageUrl = await (await imageUploadTask).ref.getDownloadURL();

        // Spremanje letka u Firestore na razini države
        await FirebaseFirestore.instance
            .collection('countries')
            .doc(normalizeCountryName('Hrvatska')) // Normaliziramo naziv države
            .collection('flyers')
            .add({
          'companyName': _companyNameController.text,
          'oib': _oibController.text,
          'pdfUrl': pdfUrl,
          'imageUrl': imageUrl,
          'startDate': Timestamp.fromDate(_startDate!),
          'endDate': Timestamp.fromDate(_endDate!),
          'showInAllCities': _showInAllCities,
        });

        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                LocalizationService.instance.translate('flyer_added') ??
                    'Flyer successfully added!'),
          ),
        );

        Navigator.pop(context); // Vraća korisnika na prethodni ekran
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  LocalizationService.instance.translate('upload_error') ??
                      'Error uploading flyer: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _endDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('create_flyer') ?? 'Create Flyer'),
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(localization.translate('uploading_to_server') ??
                      'Uploading file to server...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _companyNameController,
                      decoration: InputDecoration(
                        labelText: localization.translate('company_name') ??
                            'Company Name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localization.translate('enter_company_name') ??
                              'Enter company name';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _oibController,
                      decoration: InputDecoration(
                        labelText: localization.translate('company_oib') ??
                            'Company OIB',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length != 11) {
                          return localization
                                  .translate('enter_valid_company_oib') ??
                              'Enter valid company OIB';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      title: Text(
                          localization.translate('show_in_all_cities') ??
                              'Show in all cities'),
                      value: _showInAllCities,
                      onChanged: (value) {
                        setState(() {
                          _showInAllCities = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text(_startDate == null
                          ? localization.translate('select_start_date') ??
                              'Select start date'
                          : '${localization.translate('start_date') ?? 'Start date'}: ${DateFormat('dd.MM.yyyy').format(_startDate!)}'),
                    ),
                    ElevatedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text(_endDate == null
                          ? localization.translate('select_end_date') ??
                              'Select end date'
                          : '${localization.translate('end_date') ?? 'End date'}: ${DateFormat('dd.MM.yyyy').format(_endDate!)}'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _pickPdf,
                      child: Text(_selectedPdf == null
                          ? localization.translate('select_flyer_pdf') ??
                              'Select flyer PDF'
                          : '${localization.translate('pdf_selected') ?? 'PDF selected'}: ${_selectedPdf!.path.split('/').last}'),
                    ),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text(_selectedImage == null
                          ? localization.translate('select_flyer_image') ??
                              'Select flyer image'
                          : '${localization.translate('image_selected') ?? 'Image selected'}: ${_selectedImage!.path.split('/').last}'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _uploadFlyer,
                      child: Text(
                          localization.translate('create_flyer_button') ??
                              'Create Flyer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
