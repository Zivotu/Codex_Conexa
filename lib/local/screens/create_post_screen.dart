import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Dodano za kompresiju slika
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart';

import 'package:provider/provider.dart'; // Za pristup ChangeNotifieru
import 'package:conexa/services/localization_service.dart';
import 'package:permission_handler/permission_handler.dart'; // Dodano za kameru

import '../constants/location_constants.dart'; // Za UNKNOWN ako nedostaje

class CreatePostScreen extends StatefulWidget {
  final String localCountryId;
  final String localCityId;
  final bool isAnonymous;
  final String username;

  const CreatePostScreen({
    super.key,
    required this.localCountryId,
    required this.localCityId,
    required this.isAnonymous,
    required this.username,
  });

  @override
  CreatePostScreenState createState() => CreatePostScreenState();
}

class CreatePostScreenState extends State<CreatePostScreen>
    with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  File? _image;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  String _location = '';
  String _currentAddress = '';
  String _username = 'Korisnik';
  final PostService _postService = PostService();
  final LocationService _locationService = LocationService();
  Position? _locationData;
  double? _aspectRatio;
  String _currentNeighborhood = 'Unknown';

  /// Ovo će sadržavati listu “zgrada” (tj. neighborhood) koje su aktivne za korisnika
  List<String> _userNeighborhoodIds = [];
  String? _selectedNeighborhoodId;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadUsername();
    _loadUserNeighborhoods(); // Učitajmo korisnikove aktivne kvartove
    _takePicture(); // Odmah otvori kameru
  }

  Future<void> _requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError(Provider.of<LocalizationService>(context, listen: false)
          .translate('location_services_disabled'));
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showError(Provider.of<LocalizationService>(context, listen: false)
            .translate('location_permission_denied'));
      }
    }

    await _getLocation();
    _currentNeighborhood = await _getCurrentNeighborhood();
  }

  Future<void> _getLocation() async {
    try {
      _locationData = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (_locationData != null) {
        setState(() {
          _location =
              '${_locationData!.latitude.toStringAsFixed(6)}, ${_locationData!.longitude.toStringAsFixed(2)}';
        });

        List<Placemark> placemarks = await placemarkFromCoordinates(
            _locationData!.latitude, _locationData!.longitude);
        if (placemarks.isNotEmpty) {
          setState(() {
            _currentAddress =
                placemarks.first.subLocality ?? 'Nepoznata lokacija';
          });
        }
      }
    } catch (e) {
      debugPrint('Greška pri dobivanju lokacije: $e');
      _showError(Provider.of<LocalizationService>(context, listen: false)
          .translate('location_fetch_failed'));
    }
  }

  Future<String> _getCurrentNeighborhood() async {
    if (_locationData != null) {
      final geoData = await _locationService.getGeographicalData(
          _locationData!.latitude, _locationData!.longitude);
      return geoData['neighborhood'] ?? 'Nepoznato';
    }
    return 'Nepoznato';
  }

  /// Metoda koja provjerava dozvolu za kameru i otvara je ako je odobrena
  Future<void> _takePicture() async {
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showError(
          Provider.of<LocalizationService>(context, listen: false)
                  .translate('camera_permission_denied') ??
              'Camera permission denied',
        );
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    } else {
      Navigator.pop(context);
    }
  }

  /// Metoda za kompresiju slike
  Future<File?> _compressImage(File file) async {
    final directory = await getTemporaryDirectory();
    final targetPath =
        '${directory.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 800,
      minHeight: 600,
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> _saveImageLocally(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final originalsDir = Directory('${directory.path}/original_images');

      if (!await originalsDir.exists()) {
        await originalsDir.create(recursive: true);
      }

      final path =
          '${originalsDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await imageFile.copy(path);

      final files = originalsDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (files.length > 100) {
        for (var file in files.sublist(100)) {
          await file.delete();
          debugPrint('Izbrisana stara slika: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Greška pri spremanju slike lokalno: $e');
    }
  }

  /// Učitajmo sve “neighborhoodId” u kojima je korisnik trenutno aktivan (iz kolekcije user_locations)
  Future<void> _loadUserNeighborhoods() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(currentUser.uid)
          .collection('locations')
          .where('deleted', isEqualTo: false)
          .where('status', whereIn: ['joined', 'pending']).get();

      List<String> tempList = [];

      for (var doc in snapshot.docs) {
        final locData = doc.data();
        // Dohvat “neighborhoodId” iz glavne kolekcije “locations”
        final mainLoc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locData['locationId'])
            .get();
        if (mainLoc.exists) {
          final mainData = mainLoc.data() as Map<String, dynamic>;
          final neighId = mainData['neighborhoodId'] as String?;
          if (neighId != null && neighId.trim().isNotEmpty) {
            tempList.add(neighId);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _userNeighborhoodIds = tempList.toSet().toList();
        // Ako je samo jedna zgrada, pre‐selectajmo je
        if (_userNeighborhoodIds.length == 1) {
          _selectedNeighborhoodId = _userNeighborhoodIds.first;
        }
      });
    } catch (e) {
      debugPrint('Greška pri učitavanju korisnikovih zgrada: $e');
    }
  }

  /// Ako lokacija nije dohvaćena, više NE blokiramo korisnika
  /// Posta će se spremiti s UNKNOWN lokacijom
  Future<void> _submitPost() async {
    if (_image == null) {
      _showError(
        Provider.of<LocalizationService>(context, listen: false)
                .translate('no_image_selected') ??
            'Nema slike',
      );
      return;
    }

    /// Moramo odabrati kojem “neighborhoodId” pripada ovaj post
    if (_selectedNeighborhoodId == null) {
      _showError(
        Provider.of<LocalizationService>(context, listen: false)
                .translate('select_building') ??
            'Molimo odaberite zgradu (neighborhood).',
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Kompresija slike
      String? mediaUrl;
      {
        File? compressedImage = await _compressImage(_image!);
        if (compressedImage == null) {
          throw Exception('Kompresija slike nije uspjela');
        }
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('posts/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(compressedImage);
        mediaUrl = await storageRef.getDownloadURL();
        await compressedImage.delete();
      }

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        String postId = FirebaseFirestore.instance.collection('posts').doc().id;

        // Ako lokacija nije dohvaćena, postavljamo 'UNKNOWN'
        String usedCountryId = widget.localCountryId;
        String usedCityId = widget.localCityId;
        String usedNeighborhood = _selectedNeighborhoodId!;

        if (_locationData == null) {
          usedCountryId = LocationConstants.UNKNOWN_COUNTRY;
          usedCityId = LocationConstants.UNKNOWN_CITY;
          usedNeighborhood = LocationConstants.UNKNOWN_NEIGHBORHOOD;
        }

        Post post = Post(
          postId: postId,
          userId: currentUser.uid,
          userAge: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          likes: 0,
          dislikes: 0,
          shares: 0,
          reports: 0,
          text: _contentController.text,
          subject: '',
          views: 0,
          country: usedCountryId,
          localCountryId: usedCountryId,
          city: usedCityId,
          localCityId: usedCityId,
          neighborhood: usedNeighborhood,
          localNeighborhoodId: usedNeighborhood,
          isAnonymous: widget.isAnonymous,
          username: widget.isAnonymous ? 'Anonimus' : _username,
          deviceIdentifier: '',
          userGeoLocation: _locationData != null
              ? GeoPoint(_locationData!.latitude, _locationData!.longitude)
              : const GeoPoint(0, 0),
          postGeoLocation: _locationData != null
              ? GeoPoint(_locationData!.latitude, _locationData!.longitude)
              : const GeoPoint(0, 0),
          location: _locationData != null ? _location : 'Unknown_location',
          address: _locationData != null ? _currentAddress : 'Unknown_address',
          mediaUrl: mediaUrl,
          aspectRatio: 1.0,
          orientation: 'Portret',
        );

        // Spremanje posta u glavnu kolekciju
        await _postService.savePostToFirestore(post.toMap(), post.postId, {
          'neighborhood': usedNeighborhood,
          'cityId': usedCityId,
          'countryId': usedCountryId,
        });

        // Spremanje sažetka posta u kolekciju /events/posts/ s 'currentCityId' za notifikacije
        await FirebaseFirestore.instance
            .collection('events')
            .doc('posts')
            .collection('posts')
            .doc(post.postId)
            .set({
          'currentCityId': usedCityId,
          'postId': post.postId,
          'userId': post.userId,
          'text': post.text,
          'createdAt': FieldValue.serverTimestamp(),
          'username': post.username,
        });

        await _saveImageLocally(_image!);

        setState(() {
          _isUploading = false;
          _contentController.clear();
          _image = null;
        });

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError(
        Provider.of<LocalizationService>(context, listen: false)
            .translate('post_submission_failed'),
      );
    }
  }

  void _showError(String? message) {
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadUsername() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _username = userDoc.data()?['username'] ?? 'Korisnik';
          });
        }
      }
    } catch (e) {
      debugPrint('Greška prilikom učitavanja korisničkog imena: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${locService.translate('create_post')} - '
          '${widget.isAnonymous ? "Anonimus" : _username}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          if (_image != null)
            Positioned.fill(
              child: Image.file(
                _image!,
                fit: BoxFit.cover,
              ),
            )
          else
            Center(
              child: Text(
                locService.translate('no_image_selected') ?? 'Nema slike',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),

          // * *** DODATO: dropdown za odabir zgrade/neighborhood *** *
          if (_userNeighborhoodIds.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedNeighborhoodId,
                  dropdownColor: Colors.black87,
                  decoration: InputDecoration.collapsed(
                    hintText: locService.translate('select_building') ??
                        'Odaberite zgradu',
                  ),
                  hint: Text(
                    locService.translate('select_building') ??
                        'Odaberite zgradu',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  items: _userNeighborhoodIds.map((neighId) {
                    return DropdownMenuItem<String>(
                      value: neighId,
                      child: Text(
                        neighId,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedNeighborhoodId = val;
                    });
                  },
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: locService.translate('add_description'),
                  filled: true,
                  fillColor: Colors.black54,
                  border: InputBorder.none,
                ),
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (_isUploading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: _isUploading
          ? null
          : FloatingActionButton(
              onPressed: _submitPost,
              child: const Icon(Icons.send),
            ),
    );
  }
}
