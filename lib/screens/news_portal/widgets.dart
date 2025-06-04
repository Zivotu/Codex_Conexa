import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
