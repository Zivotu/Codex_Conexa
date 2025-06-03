import 'package:flutter/material.dart';
import '../controllers/blog_controller.dart';
import '../models/blog_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart' as io;

class EditBlogScreen extends StatefulWidget {
  final Blog blog;
  final String countryId;
  final String cityId;
  final String locationId;

  const EditBlogScreen({
    super.key,
    required this.blog,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  EditBlogScreenState createState() => EditBlogScreenState();
}

class EditBlogScreenState extends State<EditBlogScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _pollQuestionController;
  late List<TextEditingController> _pollOptionsControllers;
  late final BlogController _blogController;
  List<String> _imageUrls = []; // Rad s više slika

  @override
  void initState() {
    super.initState();
    _blogController = BlogController(
      countryId: widget.countryId,
      cityId: widget.cityId,
      locationId: widget.locationId,
    );

    _titleController = TextEditingController(text: widget.blog.title);
    _contentController = TextEditingController(text: widget.blog.content);
    _pollQuestionController =
        TextEditingController(text: widget.blog.pollQuestion);
    _pollOptionsControllers = widget.blog.pollOptions
        .map((option) => TextEditingController(text: option['option']))
        .toList();

    _imageUrls = widget.blog.imageUrls; // Učitaj slike
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      await _uploadAndSetImage(pickedFile);
    }
  }

  Future<void> _uploadAndSetImage(XFile pickedFile) async {
    try {
      final downloadUrl = await uploadImage(pickedFile);
      if (mounted) {
        setState(() {
          _imageUrls.add(downloadUrl); // Dodaj novu sliku u listu
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error uploading image: $e');
      }
    }
  }

  Future<void> _updateBlog() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showErrorSnackBar('Title and content cannot be empty');
      return;
    }

    final pollOptions = _pollOptionsControllers
        .where((controller) => controller.text.isNotEmpty)
        .map((controller) => {'option': controller.text, 'votes': 0})
        .toList();

    widget.blog.title = _titleController.text;
    widget.blog.content = _contentController.text;
    widget.blog.imageUrls = _imageUrls; // Ažuriraj slike
    widget.blog.pollQuestion = _pollQuestionController.text;
    widget.blog.pollOptions = pollOptions;

    try {
      await _blogController.updateBlog(widget.blog);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error updating blog: $e');
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

  // Widget za prikaz slika
  Widget _buildImagePreviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Slike:', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uredi Blog')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Naslov'),
              ),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Sadržaj'),
                maxLines: 10,
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.camera),
                    child: const Text('Kamera'),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: const Text('Galerija'),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              if (_imageUrls.isNotEmpty) _buildImagePreviews(),
              const SizedBox(height: 16.0),
              TextField(
                controller: _pollQuestionController,
                decoration: const InputDecoration(labelText: 'Pitanje ankete'),
              ),
              const SizedBox(height: 8.0),
              Column(
                children: _pollOptionsControllers.map((controller) {
                  return TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(labelText: 'Opcija ankete'),
                  );
                }).toList(),
              ),
              TextButton(
                onPressed: _addPollOption,
                child: const Text('Dodaj opciju ankete'),
              ),
              ElevatedButton(
                onPressed: _updateBlog,
                child: const Text('Ažuriraj'),
              ),
            ],
          ),
        ),
      ),
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
