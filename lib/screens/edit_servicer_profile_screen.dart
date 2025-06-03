import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'dart:html';
import '../models/servicer.dart';

class EditServicerProfileScreen extends StatefulWidget {
  final Servicer servicer;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const EditServicerProfileScreen({
    super.key,
    required this.servicer,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  EditServicerProfileScreenState createState() =>
      EditServicerProfileScreenState();
}

class EditServicerProfileScreenState extends State<EditServicerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceTypes = const [
    {'name': 'Vodoinstalater', 'type': '001'},
    {'name': 'Elektroinstalater', 'type': '002'},
    {'name': 'Suhi radovi', 'type': '003'}
  ];
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<String> _selectedServiceTypes = [];
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _companyNameController.text = widget.servicer.companyName;
    _addressController.text = widget.servicer.address;
    _phoneController.text = widget.servicer.phone;
    _emailController.text = widget.servicer.email;
    _descriptionController.text = widget.servicer.description;
    _selectedServiceTypes = widget.servicer.serviceType.split(', ');
    _imageUrl = widget.servicer.imageUrl;
  }

  Future<void> _pickImage() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = pickedImage;
      });
    }
  }

  Future<void> _updateServicer() async {
    if (_formKey.currentState!.validate()) {
      String? imageUrl = _imageUrl;
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('servicer_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        if (kIsWeb) {
          await ref.putData(await _selectedImage!.readAsBytes());
        } else {
          await ref.putFile(File(_selectedImage!.path));
        }
        imageUrl = await ref.getDownloadURL();
      }

      final servicerData = {
        'companyName': _companyNameController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'serviceType': _selectedServiceTypes.join(', '),
        'description': _descriptionController.text,
        'imageUrl': imageUrl ?? '',
      };

      final servicerRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('servicers')
          .doc(widget.servicer.id);

      await servicerRef.update(servicerData);
      await _updateServicerAtCityLevel(servicerData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Serviser ažuriran')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _updateServicerAtCityLevel(
      Map<String, dynamic> servicerData) async {
    final servicerRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('servicers')
        .doc(widget.servicer.id);

    await servicerRef.update(servicerData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uredi profil servisera'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_imageUrl != null && _imageUrl!.isNotEmpty)
                  Center(
                    child: Image.network(_imageUrl!, height: 200),
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Naziv tvrtke'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Unesite naziv tvrtke'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresa'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite adresu' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite telefon' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite email' : null,
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _serviceTypes.map((type) {
                    return CheckboxListTile(
                      title: Text(type['name']!),
                      value: _selectedServiceTypes.contains(type['type']),
                      onChanged: (value) {
                        setState(() {
                          if (value!) {
                            _selectedServiceTypes.add(type['type']!);
                          } else {
                            _selectedServiceTypes.remove(type['type']!);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Opis'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Unesite opis' : null,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Odaberi sliku'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateServicer,
                  child: const Text('Ažuriraj'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
