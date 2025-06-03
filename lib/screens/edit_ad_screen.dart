// lib/screens/edit_ad_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class EditAdScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final String countryId;
  final String cityId;

  const EditAdScreen({
    super.key,
    required this.ad,
    required this.countryId,
    required this.cityId,
  });

  @override
  EditAdScreenState createState() => EditAdScreenState();
}

class EditAdScreenState extends State<EditAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _linkController;
  late TextEditingController _addressController;
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;

  String? _adId;

  // Opcionalno vrijeme početka događaja
  TimeOfDay? _startTime;

  @override
  void initState() {
    super.initState();
    _adId = widget.ad['id'];
    _titleController = TextEditingController(text: widget.ad['title'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.ad['description'] ?? '');
    _linkController = TextEditingController(text: widget.ad['link'] ?? '');
    _addressController =
        TextEditingController(text: widget.ad['address'] ?? '');

    // Inicijalizacija startTime ako postoji
    if (widget.ad['startTime'] != null && widget.ad['startTime'].isNotEmpty) {
      final parts = widget.ad['startTime'].split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _addressController.dispose();
    super.dispose();
  }

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

  Future<void> _selectStartTime(BuildContext context) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
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

  Future<void> _updateAd() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String? imageUrl = widget.ad['imageUrl'];

      if (_imageFile != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child('ads').child(
              '${widget.ad['userId']}_${DateTime.now().toIso8601String()}.jpg');
          UploadTask uploadTask;
          if (kIsWeb) {
            uploadTask = ref.putData(await _imageFile!.readAsBytes());
          } else {
            uploadTask = ref.putFile(File(_imageFile!.path));
          }
          await uploadTask;
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizationService.translate('uploadError') ??
                  'Error uploading image'),
            ),
          );
          return;
        }
      }

      try {
        Map<String, dynamic> updatedAdData = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'link': _linkController.text,
          'address': _addressController.text,
          'imageUrl': imageUrl,
        };

        if (_startTime != null) {
          updatedAdData['startTime'] =
              '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
        } else {
          updatedAdData['startTime'] = '';
        }

        await FirebaseFirestore.instance
            .collection('countries')
            .doc(widget.countryId)
            .collection('cities')
            .doc(widget.cityId)
            .collection('ads')
            .doc(widget.ad['id'])
            .update(updatedAdData);

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizationService.translate('adUpdated') ??
                'Ad updated successfully'),
          ),
        );

        Navigator.pop(context, {...widget.ad, ...updatedAdData});
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizationService.translate('updateError') ??
                'Error updating ad'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('editAd') ?? 'Edit Ad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Title
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
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('description') ??
                                'Description',
                      ),
                      maxLines: 5,
                      maxLength: 400,
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
                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('address') ??
                            'Address',
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Choose Image Button
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text(
                          localizationService.translate('chooseImage') ??
                              'Choose Image'),
                    ),
                    const SizedBox(height: 10),
                    // Display selected image
                    if (_imageFile != null)
                      kIsWeb
                          ? Image.network(
                              _imageFile!.path,
                              width: 100,
                              height: 100,
                            )
                          : Image.file(
                              File(_imageFile!.path),
                              width: 100,
                              height: 100,
                            ),
                    const SizedBox(height: 20),
                    // Optional start time
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
                                    'No time selected'),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        localizationService.translate('startTimeNote') ??
                            'This field is optional.',
                      ),
                      onTap: () => _selectStartTime(context),
                    ),
                    const SizedBox(height: 20),
                    // Update Ad Button
                    ElevatedButton(
                      onPressed: _updateAd,
                      child: Text(localizationService.translate('updateAd') ??
                          'Update Ad'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
