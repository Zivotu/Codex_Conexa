import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'create_flyer_screen.dart';

class FlyersScreen extends StatelessWidget {
  final String countryId;

  const FlyersScreen({
    super.key,
    required this.countryId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letci'),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final isSuperAdmin = userData?['superadmin'] == 'true';

                if (isSuperAdmin) {
                  return IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateFlyerScreen(),
                        ),
                      );
                    },
                  );
                }
              }
              return Container();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('countries')
            .doc(countryId)
            .collection('flyers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Došlo je do greške'));
          }

          final flyers = snapshot.data?.docs ?? [];

          final now = DateTime.now();
          final filteredFlyers = flyers.where((flyer) {
            final startDate = (flyer['startDate'] as Timestamp).toDate();
            final endDate = (flyer['endDate'] as Timestamp).toDate();
            return now.isAfter(startDate) && now.isBefore(endDate);
          }).toList();

          if (filteredFlyers.isEmpty) {
            return const Center(child: Text('Nema dostupnih letaka.'));
          }

          return ListView.builder(
            itemCount: filteredFlyers.length,
            itemBuilder: (context, index) {
              final flyer =
                  filteredFlyers[index].data() as Map<String, dynamic>;
              final pdfUrl = flyer['pdfUrl'];
              final imageUrl = flyer['imageUrl'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PDFViewerScreen(pdfUrl: pdfUrl),
                    ),
                  );
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          height: 200,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PDFViewerScreen({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled Letka'),
      ),
      // Korištenje Syncfusion PDF Viewer widgeta
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}
