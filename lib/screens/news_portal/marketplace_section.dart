import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/localization_service.dart';
import '../ad_detail_screen.dart';
import '../marketplace_screen.dart';
import 'widgets.dart';

class MarketplaceSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchAds;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const MarketplaceSection({
    super.key,
    required this.fetchAds,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          buildSectionHeader(
            Icons.store,
            loc.translate('marketplace') ?? 'Tržnica',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketplaceScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children:
                      List.generate(2, (_) => buildMarketplaceAdSkeleton()),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    loc.translate('error_loading_marketplace_ads') ??
                        'Error loading marketplace ads.',
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    loc.translate('no_ads_available') ?? 'No ads available.',
                  ),
                );
              }
              final adsData = snapshot.data!;
              return Column(
                children:
                    adsData.map((ad) => _MarketplaceCard(ad: ad, loc: loc, countryId: countryId, cityId: cityId, locationId: locationId)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final LocalizationService loc;
  final String countryId;
  final String cityId;
  final String locationId;

  const _MarketplaceCard({
    required this.ad,
    required this.loc,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> adImages = ad['imageUrls'] ?? ad['images'] ?? [];
    String imageUrl = '';
    if (adImages.isNotEmpty && adImages[0] is String) {
      imageUrl = adImages[0];
    } else {
      imageUrl = ad['imageUrl'] ?? '';
    }
    final String title = ad['title'] ?? 'No Title';
    final String adDescription = ad['description'] ?? '';
    final Timestamp ts = (ad['createdAt'] is Timestamp)
        ? ad['createdAt'] as Timestamp
        : Timestamp.now();
    final DateTime createdAt = ts.toDate();
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdDetailScreen(
              ad: ad,
              countryId: countryId,
              cityId: cityId,
              locationId: locationId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            buildImage(imageUrl, width: 100, height: 100, fit: BoxFit.cover),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adDescription,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTimeAgo(createdAt, loc),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
