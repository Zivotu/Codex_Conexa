import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/user_service.dart' as user_service;
import '../services/localization_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Za spremanje zahtjeva za brisanje

class EditProfileScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const EditProfileScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  EditProfileScreenState createState() => EditProfileScreenState();
}

class EditProfileScreenState extends State<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  XFile? _profileImage;
  String?
      _selectedPredefinedImage; // Za praćenje odabrane unaprijed definirane slike

  final _auth = FirebaseAuth.instance;
  final _userService = user_service.UserService();

  // Lista unaprijed definiranih profilnih slika
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
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _userService.getUserDocument(user);
      if (userData != null) {
        _displayNameController.text = userData['displayName'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _addressController.text = userData['address'] ?? '';
        _selectedPredefinedImage = userData['profileImageUrl'];
        setState(() {});
      }
    }
  }

  // Funkcija za odabir prilagođene slike iz galerije
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = pickedFile;
        _selectedPredefinedImage =
            null; // Ukloni odabranu unaprijed definiranu sliku
      });
    }
  }

  // Funkcija za odabir unaprijed definirane slike
  void _selectPredefinedImage(String imagePath) {
    setState(() {
      _selectedPredefinedImage = imagePath;
      _profileImage = null; // Ukloni prilagođenu sliku
    });
  }

  Future<void> _updateProfile() async {
    if (_auth.currentUser != null) {
      final user = _auth.currentUser!;
      String? profileImageUrl;

      if (_selectedPredefinedImage != null) {
        profileImageUrl = _selectedPredefinedImage;
      } else if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}.jpg');
        try {
          if (kIsWeb) {
            final bytes = await _profileImage!.readAsBytes();
            await ref.putData(bytes);
          } else {
            await ref.putFile(File(_profileImage!.path));
          }
          profileImageUrl = await ref.getDownloadURL();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška pri uploadu slike: $e')),
          );
          return;
        }
      }

      await _userService.updateUserDocument(user, {
        'displayName': _displayNameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteProfile() async {
    final localization = LocalizationService.instance;
    final user = _auth.currentUser;
    if (user != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(localization.translate('confirm_deletion_title')),
          content: Text(localization.translate('confirm_deletion_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(localization.translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(localization.translate('confirm')),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final passwordController = TextEditingController();
        final authenticated = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(localization.translate('enter_password_title')),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: localization.translate('password'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(localization.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  final password = passwordController.text;
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: password,
                    );
                    await user.reauthenticateWithCredential(credential);
                    Navigator.of(ctx).pop(true);
                  } catch (_) {
                    Navigator.of(ctx).pop(false);
                  }
                },
                child: Text(localization.translate('confirm')),
              ),
            ],
          ),
        );

        if (authenticated == true) {
          // Prikaži poruku o brisanju
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar:
                  AppBar(title: Text(localization.translate('deletion_title'))),
              body: Center(
                child: Text(localization.translate('deletion_message')),
              ),
            ),
          ));

          // Spremi zahtjev za brisanje u sustav
          final now = DateTime.now();
          final deleteRequestRef =
              FirebaseFirestore.instance.collection('/delete_requests');

          try {
            await deleteRequestRef.add({
              'userId': user.uid,
              'email': user.email,
              'displayName': _displayNameController.text,
              'phone': _phoneController.text,
              'address': _addressController.text,
              'requestDate': now,
            });
            debugPrint('Zahtjev za brisanje uspješno spremljen.');
          } catch (e) {
            debugPrint('Greška pri spremanju zahtjeva za brisanje: $e');
          }
        }
      }
    }
  }

  Widget _buildPredefinedProfileImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocalizationService.instance
              .translate('select_predefined_profile_image'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _predefinedProfileImages.map((imagePath) {
            bool isSelected = _selectedPredefinedImage == imagePath;
            return GestureDetector(
              onTap: () => _selectPredefinedImage(imagePath),
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(color: Colors.blueAccent, width: 3)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(localization.translate('edit_profile'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Omogućuje skrolanje sadržaja
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Polja za unos
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                    labelText: localization.translate('display_name')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                decoration:
                    InputDecoration(labelText: localization.translate('phone')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                    labelText: localization.translate('address')),
              ),
              const SizedBox(height: 20),

              // Unaprijed definirane profilne slike
              _buildPredefinedProfileImages(),

              // Gumb za odabir prilagođene slike
              ElevatedButton(
                onPressed: _pickImage,
                child: Text(localization.translate('pick_profile_image')),
              ),
              const SizedBox(height: 20),

              // Prikaz odabrane profilne slike
              if (_selectedPredefinedImage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.translate('selected_predefined_image'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Image.asset(
                      _selectedPredefinedImage!,
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              else if (_profileImage != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.translate('selected_custom_image'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 5),
                    kIsWeb
                        ? Image.network(
                            _profileImage!.path,
                            width: 100,
                            height: 100,
                          )
                        : Image.file(
                            File(_profileImage!.path),
                            width: 100,
                            height: 100,
                          ),
                    const SizedBox(height: 10),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.translate('default_image'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Image.asset('assets/images/default_user.png',
                        width: 100, height: 100),
                    const SizedBox(height: 10),
                  ],
                ),
              const SizedBox(height: 20),

              // Gumb za ažuriranje profila
              ElevatedButton(
                onPressed: _updateProfile,
                child: Text(localization.translate('update_profile')),
              ),
              const SizedBox(height: 20),

              const Divider(),

              // Gumb za brisanje profila
              GestureDetector(
                onTap: _deleteProfile,
                child: Text(
                  localization.translate('delete_profile'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
