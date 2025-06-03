// lib/screens/adverts_info_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'register_business_screen.dart';
import '../services/localization_service.dart';
import 'create_ad_screen.dart';

class AdvertsInfoScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;

  const AdvertsInfoScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
  });

  @override
  State<AdvertsInfoScreen> createState() => _AdvertsInfoScreenState();
}

class _AdvertsInfoScreenState extends State<AdvertsInfoScreen> {
  String? _businessId;
  Map<String, dynamic>? _businessData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBusinessInfo();
  }

  Future<void> _fetchBusinessInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    final userData = userDoc.data();
    if (userData == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final businessId = userData['businessId'] as String?;
    if (businessId != null && businessId.isNotEmpty) {
      // Dohvati business dokument
      final businessDoc = await FirebaseFirestore.instance
          .collection('business_users')
          .doc(businessId)
          .get();

      if (businessDoc.exists) {
        final bd = businessDoc.data();
        setState(() {
          _businessId = businessId;
          _businessData = bd;
          _isLoading = false;
        });
      } else {
        // Business doc ne postoji ili je obrisan
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Korisnik nema businessId
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Otvara ekran za uređivanje poslovnog profila (placeholder)
  void _editBusinessProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              LocalizationService.instance.translate('edit_business_profile') ??
                  'Edit Business Profile',
            ),
          ),
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                if (_businessId == null) return;

                // Primjer "soft delete" - set 'deleted' na true
                await FirebaseFirestore.instance
                    .collection('business_users')
                    .doc(_businessId)
                    .update({'deleted': true});

                // Možda i obrišemo businessId iz users:
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({'businessId': FieldValue.delete()});
                }

                // Vratimo se nazad
                if (!mounted) return;
                Navigator.pop(context);
                Navigator.pop(context); // Zatvorimo i AdvertsInfoScreen
              },
              child: Text(
                LocalizationService.instance.translate('soft_delete_profile') ??
                    'Soft Delete (Delete Profile)',
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dohvati aktivne/povijesne oglase iz business_users/{businessId}/ads
  Widget _buildBusinessAdsList() {
    if (_businessId == null) {
      return const SizedBox.shrink();
    }

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('business_users')
            .doc(_businessId)
            .collection('ads')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                LocalizationService.instance.translate('error_loading_ads') ??
                    'Error loading ads.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                LocalizationService.instance.translate('no_ads_yet') ??
                    'No ads yet.',
              ),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final ad = docs[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: ad['imageUrl'] != null
                      ? Image.network(
                          ad['imageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image),
                  title: Text(
                    ad['title'] ??
                        LocalizationService.instance.translate('no_title') ??
                        'No title',
                  ),
                  subtitle: Text(
                    ad['description'] ??
                        LocalizationService.instance
                            .translate('no_description') ??
                        'No description',
                  ),
                  trailing: Text(
                    (ad['currentlyFree'] == true)
                        ? (LocalizationService.instance.translate('active') ??
                            'Active')
                        : (LocalizationService.instance.translate('inactive') ??
                            'Inactive'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('adverts_title') ?? 'Adverts Info',
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ako postoji business račun i nije obrisan
                  if (_businessData != null &&
                      _businessData!['deleted'] != true)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Logo
                          if (_businessData!['logoUrl'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                _businessData!['logoUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey,
                              child: const Icon(Icons.business),
                            ),
                          const SizedBox(width: 16),
                          // Naziv poduzeća
                          Expanded(
                            child: Text(
                              _businessData!['businessName'] ??
                                  localizationService
                                      .translate('business_name') ??
                                  'Business Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Ako nema business računa ili je obrisan
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        localizationService.translate('adverts_description') ??
                            'Description about adverts...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  const SizedBox(height: 30),
                  // Ako business račun NE postoji ili je obrisan -> prikaži gumb za registraciju
                  if (_businessId == null || _businessData?['deleted'] == true)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RegisterBusinessScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.app_registration,
                          color: Colors.white),
                      label: Text(
                        localizationService.translate('register') ?? 'Register',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 20),
                        textStyle:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    )
                  else
                    // Ako business račun postoji i nije obrisan -> prikaz gumba za kreiranje oglasa i uređivanje
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateAdScreen(
                                  username: widget.username,
                                  countryId: widget.countryId,
                                  cityId: widget.cityId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.create, color: Colors.white),
                          label: Text(
                            localizationService.translate('create_ad') ??
                                'Create Ad',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                            textStyle: const TextStyle(
                                fontSize: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _editBusinessProfile,
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: Text(
                            localizationService
                                    .translate('edit_business_profile') ??
                                'Edit Business Profile',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  // Prikaz liste oglasa za business account
                  if (_businessData != null &&
                      _businessData!['deleted'] != true)
                    Text(
                      localizationService.translate('your_business_ads') ??
                          'Your Business Ads:',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  if (_businessData != null &&
                      _businessData!['deleted'] != true)
                    _buildBusinessAdsList()
                  else
                    const Spacer(),
                  // Kontakt
                  if (_businessData == null ||
                      _businessData?['deleted'] == true)
                    // Ako nema biznisa, ostavimo izvorni footer
                    Center(
                      child: Column(
                        children: [
                          const Divider(color: Colors.black26),
                          const SizedBox(height: 10),
                          Text(
                            localizationService.translate('contact_us') ??
                                'Contact us',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                          ),
                          Text(
                            'info@conexa.life',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
