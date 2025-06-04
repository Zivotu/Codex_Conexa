import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/blog_model.dart';
import '../../services/localization_service.dart';
import '../blog_details_screen.dart';
import '../blog_screen.dart';
import 'widgets.dart';

class OfficialNoticesSection extends StatelessWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final String geoCountry;
  final String geoCity;
  final String geoNeighborhood;
  final bool locationAdmin;
  final FirebaseFirestore firestore;

  const OfficialNoticesSection({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.geoCountry,
    required this.geoCity,
    required this.geoNeighborhood,
    required this.locationAdmin,
    required this.firestore,
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
            Icons.campaign,
            loc.translate('official_notices') ?? 'Službene obavijesti',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlogScreen(
                    username: username,
                    countryId: countryId,
                    cityId: cityId,
                    locationId: locationId,
                  ),
                ),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('countries')
                .doc(geoCountry.isNotEmpty ? geoCountry : countryId)
                .collection('cities')
                .doc(geoCity.isNotEmpty ? geoCity : cityId)
                .collection('locations')
                .doc(geoNeighborhood.isNotEmpty ? geoNeighborhood : locationId)
                .collection('blogs')
                .orderBy('createdAt', descending: true)
                .limit(2)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('error_loading_data') ?? 'Error loading data.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      loc.translate('no_official_notices') ??
                          'No official notices available.',
                    ),
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              List<Blog> blogs = docs
                  .map((doc) => Blog.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();
              return Column(
                children: blogs.map((blog) {
                  final String imageUrl = blog.imageUrls.isNotEmpty
                      ? blog.imageUrls.first
                      : 'assets/images/tenant.png';
                  final Timestamp ts = (blog.createdAt is Timestamp)
                      ? blog.createdAt as Timestamp
                      : Timestamp.now();
                  final DateTime createdAt = ts.toDate();
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlogDetailsScreen(
                            blog: blog,
                            username: username,
                            countryId: countryId,
                            cityId: cityId,
                            locationId: locationId,
                            locationAdmin: locationAdmin,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => Image.asset(
                                        'assets/images/tenant.png',
                                        width: double.infinity,
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/tenant.png',
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black.withOpacity(0.6),
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    blog.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              blog.content.length > 100
                                  ? '${blog.content.substring(0, 100)}...'
                                  : blog.content,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              formatTimeAgo(createdAt, loc),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
