// lib/screens/register_business_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/localization_service.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({super.key});

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _taxIdController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Novo: poslovno korisničko ime i lozinka
  final TextEditingController _businessUsernameController =
      TextEditingController();
  final TextEditingController _businessPasswordController =
      TextEditingController();
  final TextEditingController _businessPasswordConfirmController =
      TextEditingController();

  XFile? _imageFile;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _registerBusiness() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Provjera lozinki
    if (_businessPasswordController.text.trim() !=
        _businessPasswordConfirmController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lozinke se ne podudaraju!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Kreiramo novi dokument za poslovnog korisnika
      final businessDocRef =
          FirebaseFirestore.instance.collection('business_users').doc();
      final String businessId = businessDocRef.id;

      // Podaci o poslovnom korisniku
      final businessData = {
        'businessId': businessId,
        'businessName': _businessNameController.text.trim(),
        'taxId': _taxIdController.text.trim(),
        'address': _addressController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        // Novo: business username i lozinka
        'businessUsername': _businessUsernameController.text.trim(),
        'businessPassword': _businessPasswordController.text.trim(),
        'userId': user.uid, // vežemo se na trenutno prijavljenog usera
        'countryId': 'Croatia', // Po želji
        'createdAt': FieldValue.serverTimestamp(),
        'deleted': false, // soft delete polje
      };

      // Upload logotipa/profilne slike (ako postoji)
      String? imageUrl;
      if (_imageFile != null) {
        // Implementacija u Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('business_logos')
            .child('$businessId.jpg');

        await ref.putFile(File(_imageFile!.path));
        imageUrl = await ref.getDownloadURL();
        businessData['logoUrl'] = imageUrl;
      } else {
        businessData['logoUrl'] = '';
      }

      // Spremi podatke u business_users
      await businessDocRef.set(businessData);

      // Ažuriraj polje "businessId" u kolekciji "users" za ovog korisnika
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'businessId': businessId});

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Business account registered successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('register_business') ??
            'Register Business'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Ime poduzeća
                    TextFormField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('business_name') ??
                                'Business Name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('error_business_name') ??
                              'Please enter the business name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // OIB / TaxID
                    TextFormField(
                      controller: _taxIdController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('tax_id') ?? 'Tax ID',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('error_tax_id') ??
                              'Please enter the tax ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                                  .translate('error_address') ??
                              'Please enter the address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Kontakt osoba
                    TextFormField(
                      controller: _contactNameController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('contact_name') ??
                                'Contact Name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizationService
                                  .translate('error_contact_name') ??
                              'Please enter the contact name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText:
                            localizationService.translate('email') ?? 'Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return localizationService.translate('error_email') ??
                              'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Telefon
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Novo: poslovno korisničko ime
                    TextFormField(
                      controller: _businessUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Business Username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Unesite poslovno korisničko ime';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Novo: poslovna lozinka
                    TextFormField(
                      controller: _businessPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Business Password',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Unesite lozinku';
                        }
                        if (value.length < 6) {
                          return 'Lozinka mora imati najmanje 6 znakova';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Potvrda lozinke
                    TextFormField(
                      controller: _businessPasswordConfirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Potvrdite lozinku';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Odaberi sliku/logotip
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text(
                          localizationService.translate('choose_image') ??
                              'Choose Image'),
                    ),
                    if (_imageFile != null) ...[
                      const SizedBox(height: 16),
                      Image.file(
                        File(_imageFile!.path),
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Gumb za registraciju
                    ElevatedButton(
                      onPressed: _registerBusiness,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        localizationService.translate('register') ?? 'Register',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
