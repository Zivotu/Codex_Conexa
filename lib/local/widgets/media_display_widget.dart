import 'package:flutter/material.dart';

class MediaDisplayWidget extends StatelessWidget {
  final String mediaUrl;
  final bool isVideo;
  final BoxFit fit; // Dodaj parametar fit

  const MediaDisplayWidget({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.fit = BoxFit.cover, // Postavi zadani fit na cover
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 50),
        ),
      );
    } else {
      // Ako je u pitanju slika, prikaži sliku
      return Image.network(
        mediaUrl,
        fit: fit, // Koristi fit parametar za kontrolu prikaza slike
        width: double.infinity, // Osiguraj da slika zauzme cijelu širinu
        height: double.infinity, // Osiguraj da slika zauzme cijelu visinu
      );
    }
  }
}
