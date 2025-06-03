// lib/screens/documents_screen.dart

import 'package:flutter/material.dart';
import 'document_list_item.dart';
import 'add_document_screen.dart';
import '../utils/document_utils.dart';
import 'document_preview_screen.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/localization_service.dart';

class DocumentsScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const DocumentsScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  DocumentsScreenState createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen> {
  final List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  final Dio _dio = Dio();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  void _loadDocuments() async {
    try {
      final documents = await fetchDocuments(
          widget.countryId, widget.cityId, widget.locationId);
      setState(() {
        _documents.addAll(documents);
        _filteredDocuments = List.from(_documents);
      });
      debugPrint('Loaded documents: $_documents');
    } catch (e) {
      debugPrint('Error loading documents: $e');
    }
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _documents.where((document) {
        final title = (document['title'] ?? '').toLowerCase();
        return title.contains(query);
      }).toList();
    });
    debugPrint("Search performed: $query");
  }

  void _showAddDocumentForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDocumentScreen(
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          username: widget.username,
          onSave: (document) {
            setState(() {
              _documents.add(document);
              _filteredDocuments.add(document);
            });
          },
        ),
      ),
    );
  }

  void _deleteDocument(int index) {
    final document = _documents[index];
    deleteDocument(widget.countryId, widget.cityId, widget.locationId,
            document['id'], document['filePath'])
        .then((_) {
      setState(() {
        _documents.removeAt(index);
        _filteredDocuments.removeWhere((doc) => doc['id'] == document['id']);
      });
    }).catchError((error) {
      debugPrint('Error deleting data: $error');
    });
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    try {
      final url = document['filePath'];
      final fileType = document['fileType'];
      final title = document['title'] ?? 'document';

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$title.$fileType';
      final file = File(filePath);

      if (!(await file.exists())) {
        await _dio.download(url, filePath);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentPreviewScreen(
            filePath: filePath,
            fileType: fileType,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('error_opening_document') ??
                'Error opening document: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('documents') ?? 'Documents'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: localization.translate('search') ?? 'Search',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      // Opcionalno: možete pozvati _performSearch() ovdje za automatsko filtriranje dok kucate
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _filteredDocuments.length,
              itemBuilder: (context, index) {
                final document = _filteredDocuments[index];
                return DocumentListItem(
                  document: document,
                  onDelete: () {
                    final originalIndex = _documents
                        .indexWhere((doc) => doc['id'] == document['id']);
                    if (originalIndex != -1) {
                      _deleteDocument(originalIndex);
                    }
                  },
                  onTap: () => _openDocument(document),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocumentForm,
        tooltip:
            localization.translate('add_new_document') ?? 'Add New Document',
        child: const Icon(Icons.add),
      ),
    );
  }
}
