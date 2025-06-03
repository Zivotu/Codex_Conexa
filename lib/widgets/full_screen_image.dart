import 'package:flutter/material.dart';
import 'dart:io'; // Dodano za rad s lokalnim datotekama

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    bool isNetwork = Uri.parse(imageUrl)
        .host
        .isNotEmpty; // Provjerite je li URL mrežni ili lokalni

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: isNetwork
            ? Image.network(imageUrl)
            : Image.file(
                File(imageUrl)), // Koristite Image.file za lokalne slike
      ),
    );
  }
}
