// lib/screens/add_bulletin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bulletin.dart';
import '../services/localization_service.dart';
import '../services/purchase_service.dart';
import '../services/user_service.dart'; // Import UserService
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator
// Import Geocoding

class AddBulletinScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;
  final void Function(Bulletin) onSave;

  const AddBulletinScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
    required this.onSave,
  });

  @override
  AddBulletinScreenState createState() => AddBulletinScreenState();
}

class AddBulletinScreenState extends State<AddBulletinScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  // Uklonjen je addressController jer se adresa zgrade automatski dohvaća
  final List<String> _imageUrls = [];
  bool _isUploading = false;

  // Options for ad type
  String _selectedAdType = 'Internal'; // 'Internal' ili 'All'

  // Radius options s unaprijed definiranim cijenama
  double _viewRadius = 1.0; // Default 1 km
  bool _isPremiumView = false;
  final Map<double, double> _radiusPrices = {
    1.0: 0.0, // Besplatno
    5.0: 5.0, // 5 USD za 5 km
    15.0: 15.0 // 15 USD za 15 km
  };

  // Geolokacija – za javne oglase koristit ćemo lokaciju zgrade
  Position? _currentPosition;

  // Services
  final PurchaseService _purchaseService = PurchaseService();
  final UserService _userService = UserService(); // Initialize UserService
  List<ProductDetails> _products = [];

  // User Balance
  double _userBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _purchaseService.initialize(_handlePurchase);
    _loadProducts();
    _fetchUserBalance();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    _purchaseService.dispose();
    super.dispose();
  }

  /// Dohvaća korisnikov balans
  Future<void> _fetchUserBalance() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      double balance = await _userService.getUserBalance(userId);
      if (mounted) {
        setState(() {
          _userBalance = balance;
        });
      }
    }
  }

  /// Dohvaća trenutnu lokaciju korisnika (ako je potrebna za interne oglase)
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.instance
                  .translate('location_service_disabled') ??
              'Location services are disabled.'),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.instance
                    .translate('location_permission_denied') ??
                'Location permission denied.'),
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.instance
                  .translate('location_permission_denied_forever') ??
              'Location permission permanently denied.'),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Greška kod dobavljanja geolokacije korisnika: $e');
    }
  }

  /// Image picking functionality
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        _uploadPickedFiles(pickedFiles);
      }
    } else {
      final XFile? singleFile = await picker.pickImage(source: source);
      if (singleFile != null) {
        _uploadPickedFiles([singleFile]);
      }
    }
  }

  /// Uploads selected images to Firebase Storage
  Future<void> _uploadPickedFiles(List<XFile> pickedFiles) async {
    setState(() {
      _isUploading = true;
    });
    for (var pickedFile in pickedFiles) {
      try {
        final downloadUrl = await _uploadImage(pickedFile);
        if (!mounted) return;
        setState(() {
          _imageUrls.add(downloadUrl);
        });
      } catch (e) {
        debugPrint('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('image_upload_failed') ??
                  'Failed to upload image.',
            ),
          ),
        );
      }
    }
    setState(() {
      _isUploading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalizationService.instance.translate('images_uploaded_success') ??
              'Images uploaded successfully.',
        ),
      ),
    );
  }

  /// Uploads a single image to Firebase Storage and returns its download URL
  Future<String> _uploadImage(XFile imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last;
      final fileName = 'bulletins/$timestamp.$fileExtension';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = storageRef.putData(await imageFile.readAsBytes());
      } else {
        uploadTask = storageRef.putFile(File(imageFile.path));
      }

      final taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Submits the bulletin to Firestore
  void _submitBulletin() async {
    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance
                    .translate('title_description_required') ??
                'Title and description are required.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('user_not_authenticated') ??
                'User not authenticated.',
          ),
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // Definirajte iznos za oduzimanje
    double amountToDeduct = 0.0;
    if (_selectedAdType == 'All') {
      amountToDeduct = _radiusPrices[_viewRadius] ?? 0.0;
    }

    // Ako je odabrana opcija "All" i radijus ima cijenu, oduzmi balans
    if (_selectedAdType == 'All' && amountToDeduct > 0.0) {
      bool balanceDeducted =
          await _userService.deductUserBalance(currentUser.uid, amountToDeduct);
      if (!balanceDeducted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.instance.translate('insufficient_balance') ??
                  'Insufficient balance for the selected option.',
            ),
          ),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    // Ako nema slika, postavi defaultnu
    if (_imageUrls.isEmpty) {
      _imageUrls.add('assets/images/bulletin.png');
    }

    // Definiraj kolekciju na temelju tipa oglasa
    CollectionReference bulletinsRef;
    if (_selectedAdType == 'All') {
      bulletinsRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('public_bullets');
    } else {
      bulletinsRef = FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('bulletin_board');
    }

    // Za javne oglase koristimo lokaciju zgrade kao referentnu točku
    GeoPoint geoPoint;
    try {
      geoPoint = await _getBuildingLocation();
    } catch (e) {
      debugPrint('Error fetching building location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('building_location_error') ??
                'Error fetching building location.',
          ),
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // Kreiraj novi Bulletin objekt
    final newBulletinRef = bulletinsRef.doc();
    final newBulletin = Bulletin(
      id: newBulletinRef.id,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      imagePaths: _imageUrls,
      likes: 0,
      dislikes: 0,
      userLiked: false,
      userDisliked: false,
      createdAt: DateTime.now(),
      comments: [],
      createdBy: currentUser.uid,
      location: geoPoint,
      // Ako je interni oglas, postavljamo default radius (npr. 0.0)
      radius: _selectedAdType == 'All' ? _viewRadius : 0.0,
      isInternal: _selectedAdType == 'Internal',
      expired: false,
    );

    // Konvertiraj u JSON
    final docData = newBulletin.toJson();
    if (_selectedAdType == 'All') {
      docData['expiresAt'] =
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 15)));
    } else {
      docData['expiresAt'] =
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 15)));
    }

    try {
      // Spremi u Firestore
      await newBulletinRef.set(docData);
    } catch (e) {
      debugPrint('Error saving bulletin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('save_bulletin_failed') ??
                'Failed to save bulletin.',
          ),
        ),
      );
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // Callback na roditeljski widget
    widget.onSave(newBulletin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalizationService.instance.translate('bulletin_created') ??
              'Bulletin created successfully.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  /// Fetches the building's location for both internal and public ads.
  /// Ako dokument sadrži polja "latitude" i "longitude", koristi ih.
  /// Inače, ako sadrži mapu "coordinates" sa "lat" i "lng", koristi te vrijednosti.
  Future<GeoPoint> _getBuildingLocation() async {
    final doc = await FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      double? lat;
      double? lng;
      if (data.containsKey('latitude') && data.containsKey('longitude')) {
        lat = (data['latitude'] as num).toDouble();
        lng = (data['longitude'] as num).toDouble();
      } else if (data.containsKey('coordinates')) {
        final coords = data['coordinates'];
        if (coords is Map) {
          if (coords.containsKey('lat') && coords.containsKey('lng')) {
            lat = (coords['lat'] as num).toDouble();
            lng = (coords['lng'] as num).toDouble();
          }
        }
      }
      if (lat != null && lng != null) {
        return GeoPoint(lat, lng);
      }
    }
    debugPrint('Building location not found, returning default GeoPoint.');
    return const GeoPoint(0.0, 0.0);
  }

  /// Handles purchasing premium balance
  Future<void> _purchasePremiumAmount(double amount) async {
    ProductDetails? product;
    if (amount == 5.0) {
      try {
        product = _products.firstWhere((p) => p.id == 'bulletin_5');
      } catch (_) {
        product = null;
      }
    } else if (amount == 15.0) {
      try {
        product = _products.firstWhere((p) => p.id == 'bulletin_15');
      } catch (_) {
        product = null;
      }
    }
    if (product != null) {
      await _purchaseService.buyProduct(product);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('product_not_found') ??
                'Product not found.',
          ),
        ),
      );
    }
  }

  /// Handles purchase updates
  void _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased) {
      String productId = purchase.productID;
      double amount = 0.0;
      if (productId == 'bulletin_5') {
        amount = 5.0;
      } else if (productId == 'bulletin_15') {
        amount = 15.0;
      }

      if (amount > 0.0) {
        bool balanceUpdated = await _userService.addUserBalance(
            FirebaseAuth.instance.currentUser!.uid, amount);
        if (balanceUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.instance.translate('purchase_success') ??
                    'Purchase successful.',
              ),
            ),
          );

          // Osvježi lokalni prikaz balansa
          double newBalance = await _userService
              .getUserBalance(FirebaseAuth.instance.currentUser!.uid);
          setState(() {
            _userBalance = newBalance;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.instance
                        .translate('balance_update_failed') ??
                    'Failed to update balance.',
              ),
            ),
          );
        }
      }
    } else if (purchase.status == PurchaseStatus.error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance.translate('purchase_failed') ??
                'Purchase failed.',
          ),
        ),
      );
    }
  }

  /// Loads available products for purchase
  Future<void> _loadProducts() async {
    final products = await _purchaseService.fetchProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizationService.translate('add_bulletin') ?? 'Add Bulletin',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Prikaz balansa
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${localizationService.translate('your_balance') ?? 'Your Balance'}: $_userBalance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Title Field
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: localizationService.translate('title') ?? 'Title',
                ),
              ),
              const SizedBox(height: 10),
              // Description Field
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: localizationService.translate('description') ??
                      'Description',
                ),
                maxLines: 4,
              ),
              // Uklonjen je unos adrese – koristimo adresu zgrade automatski
              const SizedBox(height: 10),
              // Image Picker Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      localizationService.translate('camera') ?? 'Camera',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: Text(
                      localizationService.translate('gallery') ?? 'Gallery',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              // Uploading Indicator
              if (_isUploading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(
                      localizationService.translate('uploading_images') ??
                          'Uploading images...',
                    ),
                  ],
                ),
              // Display Selected Images
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    itemBuilder: (context, index) {
                      final url = _imageUrls[index];
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: url.contains('http')
                            ? Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16.0),
              // Ad Type Dropdown
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  localizationService.translate('select_ad_type') ??
                      'Select Ad Type:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _selectedAdType,
                items: ['Internal', 'All'].map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type == 'Internal'
                          ? (localizationService.translate('internal_ad') ??
                              'Internal Ad')
                          : (localizationService.translate('all_ads') ??
                              'All Ads'),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdType = value!;
                    _isPremiumView = false;
                    if (_selectedAdType == 'All') {
                      _viewRadius = 1.0;
                    }
                  });
                },
                isExpanded: true,
              ),
              // Radius Selection for Public Ads
              if (_selectedAdType == 'All') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizationService.translate('select_radius') ??
                        'Select Radius:',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                DropdownButton<double>(
                  value: _viewRadius,
                  items: _radiusPrices.keys.map((radius) {
                    return DropdownMenuItem<double>(
                      value: radius,
                      child: Text(
                        radius == 1.0
                            ? '1 km (${localizationService.translate('free') ?? 'Free'})'
                            : '$radius km (\$${_radiusPrices[radius]!.toStringAsFixed(2)})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _viewRadius = value!;
                      _isPremiumView = _radiusPrices[_viewRadius]! > 0;
                    });
                  },
                  isExpanded: true,
                ),
                if (_isPremiumView)
                  Column(
                    children: [
                      Text(
                        localizationService
                                .translate('premium_option_selected') ??
                            'Premium option selected. Please proceed with payment.',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _purchasePremiumAmount(_viewRadius);
                        },
                        child: Text(
                          localizationService.translate('buy_balance') ??
                              'Buy Balance',
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 16.0),
              // Submit Button
              ElevatedButton(
                onPressed: _submitBulletin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                ),
                child: Text(
                  (localizationService.translate('add_bulletin') ??
                          'Add Bulletin')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
