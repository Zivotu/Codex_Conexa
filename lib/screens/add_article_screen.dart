import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:logger/logger.dart';
import '../services/localization_service.dart'; // Dodano za lokalizaciju
import 'package:firebase_auth/firebase_auth.dart';

class AddArticleScreen extends StatefulWidget {
  final String locationId;
  final String categoryField;
  final String countryId;
  final String cityId;
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? article;

  const AddArticleScreen({
    super.key,
    required this.locationId,
    required this.categoryField,
    required this.countryId,
    required this.cityId,
    required this.onSave,
    this.article,
  });

  @override
  AddArticleScreenState createState() => AddArticleScreenState();
}

class AddArticleScreenState extends State<AddArticleScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController pollQuestionController = TextEditingController();

  List<Map<String, dynamic>> pollOptions = [];
  List<String> imageUrls = [];
  bool showPollOptions = false;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    if (widget.article != null) {
      titleController.text = widget.article!['title'] ?? '';
      contentController.text = widget.article!['content'] ?? '';
      pollQuestionController.text = widget.article!['pollQuestion'] ?? '';
      pollOptions =
          List<Map<String, dynamic>>.from(widget.article!['pollOptions'] ?? []);
      imageUrls = List<String>.from(widget.article!['imageUrls'] ?? []);
      showPollOptions = pollOptions.isNotEmpty;
    }
  }

  void _addPollOption() {
    pollOptions.add({
      'id': pollOptions.length.toString(),
      'title': '',
      'votes': 0,
    });
    setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      String imageUrl = await _uploadImage(File(pickedFile.path));
      setState(() {
        imageUrls.add(imageUrl);
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    String fileName = path.basename(image.path);
    Reference storageRef =
        FirebaseStorage.instance.ref().child('articles/$fileName');
    UploadTask uploadTask = storageRef.putFile(image);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<void> _saveArticle() async {
    if (_isSaving) {
      _logger.w("Duplicate save attempt detected.");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Dohvat trenutnog jezika i prijevoda
    final localizationService = LocalizationService.instance;

    try {
      // Dohvat trenutnog korisnika
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _logger.e("User not logged in.");
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Priprema podataka za članak
      final newArticle = {
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'imageUrls': imageUrls,
        'pollQuestion': pollQuestionController.text.trim(),
        'pollOptions': pollOptions,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid, // Dodano polje "createdBy" za ID korisnika
        'authorName': user.displayName ??
            (localizationService.translate('unknown_author') ?? 'Unknown'),
      };

      // Validacija podataka
      if ((newArticle['title'] as String).isEmpty ||
          (newArticle['content'] as String).isEmpty) {
        _logger.w("Naslov ili sadržaj ne mogu biti prazni.");
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Spremanje članka u Firestore
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection(widget.categoryField)
          .add(newArticle);

      _logger.i("Article successfully saved.");

      // Poziv callback metode za ažuriranje UI-a
      widget.onSave(newArticle);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _logger.e("Error saving article: $e");
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('add_new_article')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                  titleController, localizationService.translate('title')),
              const SizedBox(height: 16.0),
              _buildTextField(
                  contentController, localizationService.translate('content'),
                  maxLines: 10),
              const SizedBox(height: 16.0),
              _buildImagePicker(),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showPollOptions = !showPollOptions;
                  });
                },
                child: Text(showPollOptions
                    ? localizationService.translate('remove_poll')
                    : localizationService.translate('add_poll')),
              ),
              if (showPollOptions) _buildPollOptions(),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _saveArticle,
                child: Text(localizationService.translate('save_article')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      maxLines: maxLines,
    );
  }

  Widget _buildImagePicker() {
    final localizationService = LocalizationService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizationService.translate('images')),
        const SizedBox(height: 8.0),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera),
              label: Text(localizationService.translate('camera')),
            ),
            const SizedBox(width: 8.0),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: Text(localizationService.translate('gallery')),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        if (imageUrls.isNotEmpty) _buildImagePreviews(),
      ],
    );
  }

  Widget _buildImagePreviews() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: imageUrls.map((url) {
        return Stack(
          children: [
            Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () {
                  setState(() {
                    imageUrls.remove(url);
                  });
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPollOptions() {
    final localizationService = LocalizationService.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(pollQuestionController,
            localizationService.translate('poll_question')),
        const SizedBox(height: 16.0),
        ...pollOptions.map((option) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText:
                    '${localizationService.translate('poll_option')} ${int.parse(option['id']) + 1}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (value) {
                option['title'] = value;
              },
            ),
          );
        }),
        const SizedBox(height: 8.0),
        ElevatedButton.icon(
          onPressed: _addPollOption,
          icon: const Icon(Icons.add),
          label: Text(localizationService.translate('add_option')),
        ),
      ],
    );
  }
}
