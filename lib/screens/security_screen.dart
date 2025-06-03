import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final bool locationAdmin;

  const SecurityScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.locationAdmin,
  });

  @override
  SecurityScreenState createState() => SecurityScreenState();
}

class SecurityScreenState extends State<SecurityScreen> {
  final Logger logger = Logger();

  void _addCamera(BuildContext context) async {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dodaj kameru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Naziv kamere'),
              ),
              TextField(
                controller: urlController,
                decoration:
                    const InputDecoration(labelText: 'IP adresa kamere'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String name = nameController.text.trim();
                final String url = urlController.text.trim();

                if (name.isNotEmpty && url.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('locations')
                        .doc(widget.locationId)
                        .collection('cameras')
                        .add({
                      'name': name,
                      'url': url,
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    logger.e('Error adding camera: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Greška prilikom dodavanja kamere')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Molimo unesite naziv i IP adresu kamere')),
                  );
                }
              },
              child: const Text('Dodaj'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeCamera(BuildContext context, String cameraId) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.locationId)
          .collection('cameras')
          .doc(cameraId)
          .delete();
    } catch (e) {
      logger.e('Error deleting camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Greška prilikom brisanja kamere')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kamere - ${widget.locationId}'),
      ),
      body: Column(
        children: [
          if (widget.locationAdmin) // Gumb za dodavanje vidljiv samo adminima
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () => _addCamera(context),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj kameru'),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('locations')
                  .doc(widget.locationId)
                  .collection('cameras')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  logger.e('Error fetching cameras: ${snapshot.error}');
                  return const Center(
                      child: Text('Greška prilikom učitavanja kamera.'));
                }
                final cameras = snapshot.data!.docs;
                if (cameras.isEmpty) {
                  return const Center(child: Text('Nema kamera za prikaz.'));
                }
                return ListView.builder(
                  itemCount: cameras.length,
                  itemBuilder: (context, index) {
                    final camera =
                        cameras[index].data() as Map<String, dynamic>;
                    final cameraName = camera['name'] ?? 'Nepoznata kamera';
                    final cameraUrl = camera['url'] ?? '';
                    return CameraThumbnail(
                      url: cameraUrl,
                      cameraName: cameraName,
                      onDelete: widget.locationAdmin
                          ? () => _removeCamera(context, cameras[index].id)
                          : null, // Brisanje omogućeno samo adminima
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CameraThumbnail extends StatelessWidget {
  final String url;
  final String cameraName;
  final VoidCallback? onDelete; // Opcionalno
  final Logger logger = Logger();

  CameraThumbnail({
    required this.url,
    required this.cameraName,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(cameraName),
          SizedBox(
            height: 200,
            child: url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (BuildContext context, Object exception,
                        StackTrace? stackTrace) {
                      logger.e(
                          'Error loading image: $exception'); // Logger greške
                      return Image.asset(
                        'assets/images/security.png', // Placeholder slika
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Image.asset(
                    'assets/images/security.png', // Placeholder slika
                    fit: BoxFit.cover,
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImage(url: url),
                    ),
                  );
                },
                child: const Text('Prikaži'),
              ),
              if (onDelete !=
                  null) // Prikazuj gumb za brisanje samo ako postoji onDelete
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String url;
  final Logger logger = Logger();

  FullScreenImage({required this.url, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object exception,
                    StackTrace? stackTrace) {
                  logger.e('Error loading image: $exception'); // Logger greške
                  return Image.asset(
                    'assets/images/security.png', // Placeholder slika
                  );
                },
              )
            : Image.asset(
                'assets/images/security.png', // Placeholder slika
              ),
      ),
    );
  }
}
