import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju

class AddDocumentScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final void Function(Map<String, dynamic>) onSave;

  const AddDocumentScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.onSave,
  });

  @override
  AddDocumentScreenState createState() => AddDocumentScreenState();
}

class AddDocumentScreenState extends State<AddDocumentScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController authorController = TextEditingController();
  File? _pickedFile;
  String? _pickedFileType;
  bool _isLoading = false;

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _pickedFileType = result.files.single.extension;
      });
    }
  }

  void _onUploadDocument() {
    if (titleController.text.isEmpty ||
        authorController.text.isEmpty ||
        _pickedFile == null) {
      _showErrorSnackBar(
        LocalizationService.instance.translate('error_missing_fields') ??
            'Please fill all fields and select a file.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _uploadDocument().then((documentData) {
      widget.onSave(documentData);
      if (mounted) {
        Navigator.pop(context);
      }
    }).catchError((e) {
      _showErrorSnackBar(
        LocalizationService.instance.translate('error_uploading_document') ??
            'Error uploading document.',
      );
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<Map<String, dynamic>> _uploadDocument() async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$_pickedFileType';
    final storageRef =
        FirebaseStorage.instance.ref().child('documents/$fileName');

    await storageRef.putFile(_pickedFile!);
    final fileUrl = await storageRef.getDownloadURL();

    final documentData = {
      'title': titleController.text,
      'author': authorController.text,
      'fileType': _pickedFileType,
      'filePath': fileUrl,
      'uploadedAt': Timestamp.now(),
      'createdAt': Timestamp.now(), // Dodajte ovo polje
      'username': widget.username,
      'countryId': widget.countryId,
      'cityId': widget.cityId,
      'locationId': widget.locationId,
    };

    await FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('documents')
        .add(documentData);

    return documentData;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('add_document') ?? 'Add Document',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: localizationService.translate('title') ?? 'Title',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorController,
              decoration: InputDecoration(
                labelText: localizationService.translate('author') ?? 'Author',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickDocument,
              child: Text(
                localizationService.translate('pick_document') ??
                    'Pick Document',
              ),
            ),
            const SizedBox(height: 10),
            if (_pickedFile != null)
              Text(
                '${localizationService.translate('picked_file') ?? 'Picked File'}: ${_pickedFile!.path.split('/').last}',
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _onUploadDocument,
                    child: Text(
                      localizationService.translate('upload_document') ??
                          'Upload Document',
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
