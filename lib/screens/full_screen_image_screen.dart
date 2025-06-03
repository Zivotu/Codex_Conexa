import 'package:flutter/material.dart';

class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;

  const FullScreenImageScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Scaffold(
        body: Center(
          child: imagePath.isNotEmpty
              ? Image.asset(imagePath)
              : const Text(
                  'No image available'), // Prikazuje tekst ako imagePath nije postavljen
        ),
      ),
    );
  }
}
