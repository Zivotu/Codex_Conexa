// lib/screens/create_blog_screen.dart

import 'package:flutter/material.dart';
import '../controllers/blog_controller.dart';
import '../models/blog_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart' as io;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';

class CreateBlogScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const CreateBlogScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  CreateBlogScreenState createState() => CreateBlogScreenState();
}

class CreateBlogScreenState extends State<CreateBlogScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionsControllers = [
    TextEditingController(),
    TextEditingController()
  ];
  late final BlogController _blogController;
  final List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _blogController = BlogController(
      countryId: widget.countryId,
      cityId: widget.cityId,
      locationId: widget.locationId,
    );
  }

  Future<void> _pickImages(ImageSource source) async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    for (var pickedFile in pickedFiles) {
      await _uploadAndSetImage(pickedFile);
    }
  }

  Future<void> _uploadAndSetImage(XFile pickedFile) async {
    try {
      final downloadUrl = await uploadImage(pickedFile);
      if (mounted) {
        setState(() {
          _imageUrls.add(downloadUrl);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            LocalizationService.instance.translate('upload_image_error') ??
                'Error uploading image: $e');
      }
    }
  }

  Future<void> _submitBlog() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showErrorSnackBar(
          LocalizationService.instance.translate('empty_fields_error') ??
              'Title and content must not be empty.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar(
          LocalizationService.instance.translate('user_not_logged_in') ??
              'You must be logged in to post a blog.');
      return;
    }

    final pollOptions = _pollOptionsControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => {'option': controller.text, 'votes': 0})
        .toList();

    final blog = Blog(
      id: '',
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: DateTime.now(),
      author: widget.username,
      createdBy: user.uid,
      imageUrls: _imageUrls,
      pollQuestion: _pollQuestionController.text.trim(),
      pollOptions: pollOptions,
      votedUsers: [],
    );

    try {
      await _blogController.createBlog(blog);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
            LocalizationService.instance.translate('create_blog_error') ??
                'Error creating blog: $e');
      }
    }
  }

  void _addPollOption() {
    setState(() {
      _pollOptionsControllers.add(TextEditingController());
    });
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
    final localization = LocalizationService.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('create_blog') ?? 'Create Blog'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                  _titleController, localization.translate('title') ?? 'Title'),
              _buildTextField(_contentController,
                  localization.translate('content') ?? 'Content',
                  maxLines: 10),
              const SizedBox(height: 16.0),
              // Slika
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImages(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(localization.translate('camera') ?? 'Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImages(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(localization.translate('gallery') ?? 'Gallery'),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              if (_imageUrls.isNotEmpty) _buildImagePreviews(),
              // Anketa
              _buildTextField(_pollQuestionController,
                  localization.translate('poll_question') ?? 'Poll Question'),
              const SizedBox(height: 8.0),
              Column(
                children: _pollOptionsControllers.map((controller) {
                  return _buildTextField(controller,
                      localization.translate('poll_option') ?? 'Poll Option');
                }).toList(),
              ),
              TextButton(
                onPressed: _addPollOption,
                child: Text(localization.translate('add_poll_option') ??
                    'Add Poll Option'),
              ),
              // Submit
              ElevatedButton(
                onPressed: _submitBlog,
                child: Text(
                    localization.translate('submit_blog') ?? 'Submit Blog'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildImagePreviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocalizationService.instance.translate('image_preview') ??
              'Image Preview:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _imageUrls.map((imageUrl) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Future<String> uploadImage(XFile imageFile) async {
  try {
    String fileName =
        'blogs/${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    UploadTask uploadTask;

    if (kIsWeb) {
      uploadTask = storageRef.putData(await imageFile.readAsBytes());
    } else {
      uploadTask = storageRef.putFile(io.File(imageFile.path));
    }

    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  } catch (e) {
    debugPrint('Error uploading image: $e');
    rethrow;
  }
}
