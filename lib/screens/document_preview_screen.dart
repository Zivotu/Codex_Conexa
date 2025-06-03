import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:video_player/video_player.dart';
import 'package:open_file/open_file.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileType;

  const DocumentPreviewScreen({
    super.key,
    required this.filePath,
    required this.fileType,
  });

  @override
  DocumentPreviewScreenState createState() => DocumentPreviewScreenState();
}

class DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPdfLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.fileType.toLowerCase() == 'video') {
      _videoController = VideoPlayerController.file(File(widget.filePath))
        ..initialize().then((_) {
          setState(() {
            _isVideoInitialized = true;
          });
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildFilePreview() {
    switch (widget.fileType.toLowerCase()) {
      case 'image':
        return Center(
          child: Image.file(
            File(widget.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error);
            },
          ),
        );
      case 'pdf':
        return PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: true,
          autoSpacing: false,
          pageFling: false,
          onRender: (pages) {
            setState(() {
              _isPdfLoaded = true;
            });
          },
          onError: (error) {
            debugPrint('Error rendering PDF: $error');
          },
          onPageError: (page, error) {
            debugPrint('Error on page $page: $error');
          },
        );
      case 'video':
        if (_isVideoInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Ova datoteka se ne može otvoriti.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  OpenFile.open(widget.filePath);
                },
                child: const Text('Preuzmi ili Podijeli'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled datoteke'),
        actions: widget.fileType.toLowerCase() == 'video' && _isVideoInitialized
            ? [
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                ),
              ]
            : null,
      ),
      body: _buildFilePreview(),
      floatingActionButton:
          widget.fileType.toLowerCase() == 'pdf' && _isPdfLoaded
              ? FloatingActionButton(
                  onPressed: () {
                    // Dodajte funkcionalnost preuzimanja ili dijeljenja PDF-a ako je potrebno
                    OpenFile.open(widget.filePath);
                  },
                  child: const Icon(Icons.download),
                )
              : null,
    );
  }
}
