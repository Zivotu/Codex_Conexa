import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'edit_profile_screen.dart'; // Provjerite ovu liniju

class ProfileScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final String locationName; // Dodavanje varijable za ime lokacije

  const ProfileScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationName, // Dodavanje varijable za ime lokacije
  });

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        userData = await _userService.getUserDocument(user);
        if (userData != null) {
          setState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('User data not found'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 80,
                        backgroundImage: _getProfileImage(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${userData?['displayName'] ?? 'User'} ${userData?['lastName'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildUserInfo('Username', userData?['username']),
                      _buildUserInfo('Email', userData?['email']),
                      _buildUserInfo('Phone', userData?['phone']),
                      _buildUserInfo('Address', userData?['address']),
                      _buildUserInfo('Country', widget.countryId),
                      _buildUserInfo('City', widget.cityId),
                      _buildUserInfo('Location',
                          widget.locationName), // Prikaz imena lokacije
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Navigacija na edit_profile_screen.dart
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(
                                username: widget.username,
                                countryId: widget.countryId,
                                cityId: widget.cityId,
                                locationId: widget.locationId,
                              ),
                            ),
                          );
                        },
                        child: const Text('Promijeni'), // Gumb "Promijeni"
                      ),
                    ],
                  ),
                ),
    );
  }

  ImageProvider<Object> _getProfileImage() {
    if (userData?['profileImageUrl'] != null &&
        userData!['profileImageUrl'].isNotEmpty &&
        !userData!['profileImageUrl'].startsWith('assets/')) {
      return NetworkImage(userData!['profileImageUrl']);
    } else {
      return const AssetImage('assets/images/default_user.png');
    }
  }

  Widget _buildUserInfo(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            value ?? 'N/A',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
