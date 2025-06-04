import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/localization_service.dart';

/// Common helper widgets and functions for the news portal sections.
Widget buildSectionHeader(
    IconData iconData, String title, VoidCallback onTap, {Color? headerColor}) {
  return ListTile(
    onTap: onTap,
    leading: Icon(iconData, size: 28, color: headerColor ?? Colors.blueAccent),
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );
}

Widget buildImage(String? imageUrl,
    {double width = 80, double height = 80, BoxFit fit = BoxFit.cover}) {
  if (imageUrl != null && imageUrl.isNotEmpty) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey,
          child: const Icon(Icons.image, color: Colors.white),
        ),
      );
    } else {
      return Image.asset(imageUrl, width: width, height: height, fit: fit);
    }
  }
  return Image.asset('assets/images/tenant.png',
      width: width, height: height, fit: fit);
}

String formatTimeAgo(DateTime dateTime, LocalizationService loc) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inSeconds < 60) {
    return loc.translate('just_now') ?? 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${loc.translate('minutes_ago') ?? 'minutes ago'}';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} ${loc.translate('hours_ago') ?? 'hours ago'}';
  }
  return '${diff.inDays} ${loc.translate('days_ago') ?? 'days ago'}';
}

String formatDateTime(DateTime date, String time) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} $time';
}

/// Generic shimmer wrapper used for skeleton placeholders.
Widget buildShimmer(Widget child) {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: child,
  );
}

/// Skeleton for a simple list tile card (bulletins, documents).
Widget buildListTileSkeleton() {
  return buildShimmer(
    Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(width: 48, height: 48, color: Colors.grey[300]),
        title: Container(height: 16, color: Colors.grey[300]),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 8),
          height: 12,
          width: 100,
          color: Colors.grey[300],
        ),
      ),
    ),
  );
}

/// Skeleton for chat message preview.
Widget buildChatMessageSkeleton() {
  return buildShimmer(
    Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 100, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(height: 14, color: Colors.grey[300]),
                  const SizedBox(height: 4),
                  Container(height: 12, width: 80, color: Colors.grey[300]),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Skeleton for marketplace ads.
Widget buildMarketplaceAdSkeleton() {
  return buildShimmer(
    Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(width: 100, height: 100, color: Colors.grey[300]),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(height: 14, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 80, color: Colors.grey[300]),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Skeleton for blog/notice cards.
Widget buildBlogPostSkeleton() {
  return buildShimmer(
    Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 150, color: Colors.grey[300]),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(height: 14, color: Colors.grey[300]),
                const SizedBox(height: 4),
                Container(height: 12, width: 80, color: Colors.grey[300]),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Skeleton for quiz leaderboard entries.
Widget buildQuizResultSkeleton() {
  return buildShimmer(
    Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey,
          ),
        ),
        title: Container(height: 16, color: Colors.grey[300]),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 8),
          height: 12,
          width: 80,
          color: Colors.grey[300],
        ),
      ),
    ),
  );
}

/// Grid skeleton for the latest posts preview.
Widget buildPostsGridSkeleton() {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1,
    ),
    itemBuilder: (context, index) => buildShimmer(
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(color: Colors.grey[300]),
      ),
    ),
  );
}
