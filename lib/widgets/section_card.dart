import 'package:flutter/material.dart';

/// A reusable card widget with a header and custom body content.
class SectionCard extends StatelessWidget {
  /// Leading icon shown in the header.
  final IconData icon;

  /// Title displayed in the header.
  final String title;

  /// Callback triggered when the header is tapped.
  final VoidCallback onTap;

  /// The body of the card displayed below the header.
  final Widget child;

  /// Background color of the card.
  final Color? cardColor;

  /// Color of the icon in the header.
  final Color? headerColor;

  /// Margin around the card.
  final EdgeInsetsGeometry margin;

  /// Padding applied around the body widget.
  final EdgeInsetsGeometry bodyPadding;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.child,
    this.cardColor,
    this.headerColor,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.bodyPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Icon(icon, size: 28, color: headerColor ?? Colors.blueAccent),
            title: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          Padding(
            padding: bodyPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}
