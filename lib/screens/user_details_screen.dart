import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import 'package:logger/logger.dart';

class UserDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final String locationId;
  final String countryId;
  final String cityId;

  UserDetailsScreen({
    super.key,
    required this.userData,
    required this.userId,
    required this.locationId,
    required this.countryId,
    required this.cityId,
  });

  final Logger _logger = Logger();

  /// Ako u proslijeđenom userData nedostaje lastName, dohvaća se iz root kolekcije 'users'
  Future<Map<String, dynamic>> _getUserDetails() async {
    if (userData['lastName'] != null &&
        (userData['lastName'] as String).trim().isNotEmpty) {
      return userData;
    } else {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final fallbackData = doc.data() as Map<String, dynamic>;
        final mergedData = {...userData};
        mergedData['lastName'] = fallbackData['lastName'] ?? '';
        return mergedData;
      }
      return userData;
    }
  }

  Future<void> _updateUserField(
      BuildContext context, String field, dynamic value) async {
    final userService = Provider.of<UserService>(context, listen: false);

    if (field == 'locationAdmin') {
      try {
        await userService.updateLocationAdminStatus(
          userId: userId,
          countryId: countryId,
          cityId: cityId,
          locationId: locationId,
          isAdmin: value,
        );
        if (context.mounted) {
          _showSnackBar(
              context,
              value
                  ? 'Administratorska prava dodijeljena'
                  : 'Administratorska prava uklonjena');
        }
      } catch (e) {
        _logger.e("Error updating locationAdmin: $e");
        if (context.mounted) {
          _showSnackBar(
              context, 'Greška pri ažuriranju administrativnih prava.');
        }
      }
    } else {
      try {
        // Ažuriramo u lokacijskoj kolekciji
        await FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('cities')
            .doc(cityId)
            .collection('locations')
            .doc(locationId)
            .collection('users')
            .doc(userId)
            .update({field: value});
        // Repliciramo ažuriranje i u globalnoj 'users' kolekciji
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({field: value});
        if (context.mounted) {
          String message;
          if (field == 'chatBlocked') {
            message = value ? 'Chat blokiran' : 'Chat dopušten';
          } else if (field == 'blocked') {
            message = value ? 'Svi unosi blokirani' : 'Svi unosi dopušteni';
          } else {
            message = '';
          }
          _showSnackBar(context, message);
        }
      } catch (e) {
        _logger.e("Error updating field '$field': $e");
        if (context.mounted) {
          _showSnackBar(context, 'Greška pri ažuriranju polja.');
        }
      }
    }
  }

  Future<void> _deleteUserEntries(BuildContext context) async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('countries')
          .doc(countryId)
          .collection('cities')
          .doc(cityId)
          .collection('locations')
          .doc(locationId)
          .collection('chatMessages')
          .where('userId', isEqualTo: userId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _showSnackBar(context, 'Svi unosi korisnika su izbrisani.');
    } catch (e) {
      _showSnackBar(context, 'Greška pri brisanju unosa: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildProfileImage(Map<String, dynamic> data) {
    final profileImageUrl = (data['profileImageUrl'] as String?)?.trim() ?? '';
    if (profileImageUrl.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Image(
            image: profileImageUrl.startsWith('http')
                ? NetworkImage(profileImageUrl)
                : AssetImage(profileImageUrl) as ImageProvider,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.grey);
            },
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Image.asset(
            'assets/images/default_user.png',
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detalji korisnika'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Detalji korisnika'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: Center(child: Text('Greška pri dohvaćanju podataka.')),
          );
        }

        final data = snapshot.data!;
        bool isAdmin = data['locationAdmin'] == true;
        bool isChatBlocked = data['chatBlocked'] == true;
        bool isBlocked = data['blocked'] == true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalji korisnika'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Center(child: _buildProfileImage(data)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${data['displayName'] ?? ''} ${data['lastName'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Korisničko ime: ${data['username'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Email: ${data['email'] ?? ''}'),
                Text('Kat: ${data['floor'] ?? ''}'),
                Text('Broj apartmana: ${data['apartmentNumber'] ?? ''}'),
                Text('Telefon: ${data['phone'] ?? ''}'),
                Text('Adresa: ${data['address'] ?? ''}'),
                Text('Država: ${data['countryId'] ?? ''}'),
                Text('Grad: ${data['cityId'] ?? ''}'),
                Text(
                  'Pridružio se: ${_formatTimestamp(data['joinedAt'] as Timestamp?)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _updateUserField(
                          context, 'locationAdmin', !isAdmin);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isAdmin
                          ? 'Oduzmi administratorska prava'
                          : 'Postavi za Administratora',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await _updateUserField(
                            context, 'chatBlocked', !isChatBlocked);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isChatBlocked ? 'Dopusti chat' : 'Blokiraj CHAT',
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _updateUserField(context, 'blocked', !isBlocked);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isBlocked ? 'Dopusti sve unose' : 'Blokiraj SVE unose',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _deleteUserEntries(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Izbriši sve unose korisnika',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
