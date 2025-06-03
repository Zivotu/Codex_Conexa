import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SinglePdfScreen extends StatelessWidget {
  final String pdfPath = 'assets/flyers/flyer_1.pdf'; // Putanja do PDF-a

  const SinglePdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled Letka'),
      ),
      body: SfPdfViewer.asset(pdfPath), // Prikaz PDF-a direktno iz asseta
    );
  }
}
