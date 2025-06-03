// C:\Conexa_11f\lib\widgets\category_card.dart

import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final String route;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final VoidCallback? onDelete;
  final bool? isActive;
  final int newMessagesCount;
  final VoidCallback? onTap;
  final String? subtitle; // Dodajte subtitle kao opcionalni parametar

  const CategoryCard({
    super.key,
    required this.title,
    required this.imagePath,
    required this.route,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    this.onDelete,
    this.isActive,
    required this.newMessagesCount,
    this.onTap,
    this.subtitle, // Inicijalizirajte subtitle
  });

  bool get isNetworkImage => imagePath.startsWith('http');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.pushNamed(
              context,
              route,
              arguments: {
                'username': username,
                'countryId': countryId,
                'cityId': cityId,
                'locationId': locationId,
              },
            );
          },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Stack(
          children: [
            // Prikaz mrežne ili lokalne slike
            ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: isNetworkImage
                  ? Image.network(
                      imagePath,
                      height: 200.0,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/feedback.png', // Zadana slika u slučaju greške
                          height: 200.0,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      imagePath.isNotEmpty
                          ? imagePath
                          : 'assets/images/feedback.png',
                      height: 200.0,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/feedback.png', // Zadana slika u slučaju greške
                          height: 200.0,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
            ),
            // Badge za broj novosti na gornjem lijevom kutu
            if (newMessagesCount > 0)
              Positioned(
                top: 8.0,
                left: 8.0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  child: Text(
                    '$newMessagesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // Indikator aktivnosti na gornjem desnom kutu
            if (isActive != null)
              Positioned(
                top: 8.0,
                right: 8.0,
                child: Image.asset(
                  isActive!
                      ? 'assets/images/green_light_1.png'
                      : 'assets/images/red_light_1.png',
                  width: 24,
                  height: 24,
                ),
              ),
            // Dugme za brisanje ako je definirano
            if (onDelete != null)
              Positioned(
                top: 8.0,
                right: 8.0,
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ),
            // Naslov na dnu kartice
            Positioned(
              bottom: 16.0,
              left: 16.0,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Color.fromARGB(137, 226, 226, 226),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
