// lib/screens/settings_edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart'; // Added for LocalizationService
import '../services/user_service.dart' as user_service;
import '../services/localization_service.dart'; // Import LocalizationService

class SettingsEditProfileScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final String userId;

  const SettingsEditProfileScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.userId,
  });

  @override
  SettingsEditProfileScreenState createState() =>
      SettingsEditProfileScreenState();
}

class SettingsEditProfileScreenState extends State<SettingsEditProfileScreen> {
  final _emailController = TextEditingController();
  final _usernameController =
      TextEditingController(); // Added field for username
  final _displayNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _floorController = TextEditingController();
  final _apartmentNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  XFile? _profileImage;
  String? _selectedPredefinedImage; // To track the selected predefined image
  String? _profileImageUrl;
  final user_service.UserService userService = user_service.UserService();

  // List of predefined profile images
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
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _lastNameController.dispose();
    _floorController.dispose();
    _apartmentNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await userService.getUserDocument(user);
      if (data != null) {
        _emailController.text = data['email'] ?? '';
        _usernameController.text = data['username'] ?? ''; // Loading username
        _displayNameController.text = data['displayName'] ?? '';
        _lastNameController.text = data['lastName'] ?? '';
        _floorController.text = data['floor'] ?? '';
        _apartmentNumberController.text = data['apartmentNumber'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _profileImageUrl = data['profileImageUrl'];
        if (_predefinedProfileImages.contains(_profileImageUrl)) {
          _selectedPredefinedImage = _profileImageUrl;
        }
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  // Function to pick a custom image from the gallery
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = pickedFile;
        _selectedPredefinedImage = null; // Remove the selected predefined image
      });
    }
  }

  // Function to select a predefined image
  void _selectPredefinedImage(String imagePath) {
    setState(() {
      _selectedPredefinedImage = imagePath;
      _profileImage = null; // Remove the custom image
      _profileImageUrl = imagePath;
    });
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? profileImageUrl = _profileImageUrl;
      if (_profileImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${user.uid}.jpg');
        UploadTask uploadTask;
        try {
          if (kIsWeb) {
            final bytes = await _profileImage!.readAsBytes();
            uploadTask = ref.putData(bytes);
          } else {
            uploadTask = ref.putFile(File(_profileImage!.path));
          }
          await uploadTask;
          profileImageUrl = await ref.getDownloadURL();
        } catch (e) {
          final localizationService =
              Provider.of<LocalizationService>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    localizationService.translate('error_upload_image') ??
                        'Error uploading image: $e')),
          );
          return;
        }
      }

      await userService.updateUserDocument(user, {
        'email': _emailController.text,
        'username': _usernameController.text, // Saving username
        'displayName': _displayNameController.text,
        'lastName': _lastNameController.text,
        'floor': _floorController.text,
        'apartmentNumber': _apartmentNumberController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'profileImageUrl': profileImageUrl,
      });

      if (!mounted) return;
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localizationService.translate('profile_updated') ??
                'Profile updated')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildProfileImage() {
    if (_profileImage != null) {
      return kIsWeb
          ? Image.network(_profileImage!.path, width: 100, height: 100)
          : Image.file(File(_profileImage!.path), width: 100, height: 100);
    } else if (_selectedPredefinedImage != null) {
      return Image.asset(
        _selectedPredefinedImage!,
        width: 100,
        height: 100,
      );
    } else if (_profileImageUrl != null &&
        _profileImageUrl!.startsWith('http')) {
      return Image.network(_profileImageUrl!, width: 100, height: 100);
    } else {
      return Image.asset('assets/images/default_user.png',
          width: 100, height: 100);
    }
  }

  Widget _buildPredefinedProfileImages(
      LocalizationService localizationService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizationService.translate('select_predefined_profile_image') ??
              'Select a predefined profile image',
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
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            localizationService.translate('edit_profile') ?? 'Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Predefined Profile Images
            _buildPredefinedProfileImages(localizationService),

            // Button to pick a custom image
            ElevatedButton(
              onPressed: _pickImage,
              child: Text(localizationService
                      .translate('pick_profile_image_from_gallery') ??
                  'Pick Profile Image from Gallery'),
            ),
            const SizedBox(height: 20),

            // Display selected profile image
            _buildProfileImage(),
            const SizedBox(height: 20),

            // Input Fields
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                  labelText:
                      localizationService.translate('username') ?? 'Username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _displayNameController,
              decoration: InputDecoration(
                  labelText: localizationService.translate('first_name') ??
                      'First Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                  labelText: localizationService.translate('last_name') ??
                      'Last Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                  labelText: localizationService.translate('email') ?? 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _floorController,
              decoration: InputDecoration(
                  labelText: localizationService.translate('floor') ?? 'Floor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _apartmentNumberController,
              decoration: InputDecoration(
                  labelText:
                      localizationService.translate('apartment_number') ??
                          'Apartment Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                  labelText: localizationService.translate('phone_number') ??
                      'Phone Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                  labelText:
                      localizationService.translate('address') ?? 'Address'),
            ),
            const SizedBox(height: 20),

            // Button to save profile
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(localizationService.translate('save_profile') ??
                  'Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
