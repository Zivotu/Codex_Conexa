// lib/screens/ad_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/map_view_screen.dart';
import 'edit_ad_screen.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class AdDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final String countryId;
  final String cityId;
  final String locationId;
  const AdDetailScreen({
    super.key,
    required this.ad,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  late Map<String, dynamic> ad;

  @override
  void initState() {
    super.initState();
    ad = widget.ad; // Initialize with the passed ad
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    final String imageUrl = ad['imageUrl'] ?? '';
    final String title =
        ad['title'] ?? localizationService.translate('noTitle') ?? 'No Title';
    final String description = ad['description'] ??
        localizationService.translate('noDescription') ??
        'No Description';
    final String address = ad['address'] ??
        localizationService.translate('noAddress') ??
        'No Address';
    final String link = ad['link'] ?? '';
    final String startTime = ad['startTime'] ?? '';

    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    final bool isCreator = user != null && ad['userId'] == user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                // Navigate to EditAdScreen and wait for updated ad
                final updatedAd = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAdScreen(
                      ad: ad,
                      countryId: widget.countryId,
                      cityId: widget.cityId,
                    ),
                  ),
                );

                if (updatedAd != null) {
                  // Update local state with updated ad
                  setState(() {
                    ad = updatedAd;
                  });
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              _shareAd(ad);
            },
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              _showMap(context, address);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/marketplace_1.jpg',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  )
                : Image.asset(
                    'assets/images/marketplace_1.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${localizationService.translate('address') ?? 'Address'}: $address',
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Prikaz poveznice ako postoji
                  if (link.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.link, size: 36, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            link,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Prikaz vremena početka ako postoji
                  if (startTime.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time,
                            size: 36, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text(
                          startTime,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAd(Map<String, dynamic> ad) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    // Maksimalni broj znakova opisa u dijeljenoj poruci
    const int maxDescriptionLength = 500;

    // Skraćeni opis s provjerom duljine
    String truncatedDescription = ad['description'] ?? '';
    if (truncatedDescription.length > maxDescriptionLength) {
      truncatedDescription =
          '${truncatedDescription.substring(0, maxDescriptionLength)}...';
    }

    // Kreiranje poruke za dijeljenje s lokaliziranim ključevima
    final String text = '''
${ad['title'] ?? ''}
$truncatedDescription

${ad['address'] ?? ''}
${ad['startTime'] != null && ad['startTime'].isNotEmpty ? '${localizationService.translate('time') ?? 'Time'}: ${ad['startTime']}' : ''}
${ad['link'] != null && ad['link'].isNotEmpty ? '${localizationService.translate('link') ?? 'Link'}: ${ad['link']}' : ''}

Conexa.life
''';

    if (ad['imageUrl'] != null && ad['imageUrl'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(ad['imageUrl']));
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, 'shared_image.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles([XFile(file.path)], text: text);
      } catch (e) {
        debugPrint('Error sharing image: $e');
        await Share.share(text);
      }
    } else {
      await Share.share(text);
    }
  }

  void _showMap(BuildContext context, String address) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return MapViewScreen(
            latitude: ad['coordinates']['lat'],
            longitude: ad['coordinates']['lng'],
            address: address,
          );
        },
        fullscreenDialog: true,
      ),
    );
  }
}
