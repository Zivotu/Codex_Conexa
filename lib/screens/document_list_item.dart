import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DocumentListItem extends StatefulWidget {
  final Map<String, dynamic> document;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const DocumentListItem({
    super.key,
    required this.document,
    required this.onDelete,
    required this.onTap,
  });

  @override
  _DocumentListItemState createState() => _DocumentListItemState();
}

class _DocumentListItemState extends State<DocumentListItem> {
  bool _isSharing = false;
  bool _isDownloading = false;

  Future<void> _shareDocument(BuildContext context) async {
    setState(() {
      _isSharing = true;
    });

    try {
      final url = widget.document['filePath'];
      final fileType = widget.document['fileType'];
      final title = widget.document['title'] ?? 'document';
      final dio = Dio();

      // Dobijte direktorij za privremene datoteke
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$title.$fileType';

      final file = File(filePath);

      // Provjerite postoji li datoteka već
      if (!await file.exists()) {
        // Preuzmite datoteku
        await dio.download(url, filePath);
      }

      // Dijelite lokalnu datoteku
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Evo dokumenta: $title',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e')),
      );
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  Future<void> _downloadDocument(BuildContext context) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final url = widget.document['filePath'];
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/${widget.document['title']}.${widget.document['fileType']}';
      await Dio().download(url, path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading document: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  IconData getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  bool isImageFile(String filePath) {
    return filePath.toLowerCase().endsWith('.jpg') ||
        filePath.toLowerCase().endsWith('.jpeg') ||
        filePath.toLowerCase().endsWith('.png');
  }

  @override
  Widget build(BuildContext context) {
    final String fileType = widget.document['fileType'] ?? 'unknown';
    final String filePath = widget.document['filePath'] ?? '';
    final bool isImage = isImageFile(filePath);
    final double imageSize = MediaQuery.of(context).size.width / 4;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: isImage
                    ? Image.network(
                        filePath,
                        width: imageSize,
                        height: imageSize,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(getFileIcon(fileType), size: imageSize);
                        },
                      )
                    : Icon(getFileIcon(fileType), size: imageSize),
              ),
            ),
          ),
          Text(
            widget.document['title'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            widget.document['author'],
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            children: [
              _isSharing
                  ? CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _shareDocument(context),
                    ),
              _isDownloading
                  ? CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadDocument(context),
                    ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: widget.onTap,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
