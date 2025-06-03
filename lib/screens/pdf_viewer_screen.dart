import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PDFViewerScreen({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled Letka'),
      ),
      // Directno učitavanje PDF-a sa mreže preko Syncfusion widgeta
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}
