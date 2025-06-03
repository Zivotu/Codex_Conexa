// lib/screens/bulletin_board_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bulletin.dart';
import '../widgets/bulletin_list_item.dart';
import '../services/user_service.dart';
import '../services/localization_service.dart';
import '../services/purchase_service.dart';
import 'add_bulletin_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'full_screen_bulletin.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class BulletinBoardScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const BulletinBoardScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  BulletinBoardScreenState createState() => BulletinBoardScreenState();
}

class BulletinBoardScreenState extends State<BulletinBoardScreen> {
  final List<Bulletin> _bulletins = [];

  // Referentne kolekcije za interne i javne oglase
  CollectionReference? _internalBulletinsRef;
  CollectionReference? _publicBulletinsRef;

  String locationName = '';
  bool isLocationAdmin = false;
  final UserService _userService = UserService();

  // Vrsta oglasa: 'Internal' ili 'All'
  String _selectedAdType = 'Internal';

  // Kontrola za lazy loading
  final int _limit = 10;
  DocumentSnapshot? _lastInternalDocument;
  DocumentSnapshot? _lastPublicDocument;
  bool _isLoadingMoreInternal = false;
  bool _isLoadingMorePublic = false;
  bool _hasMoreInternal = true;
  bool _hasMorePublic = true;
  final ScrollController _scrollController = ScrollController();

  // Lokacija zgrade
  GeoPoint? _buildingLocation;

  // Korisnička lokacija (više se neće koristiti za filtriranje javnih oglasa)
  Position? _userPosition;

  // PurchaseService (ako koristite kupnje)
  final PurchaseService _purchaseService = PurchaseService();
  List<ProductDetails> _products = [];

  // Balans korisnika
  double _userBalance = 0.0;

  @override
  void initState() {
    super.initState();

    // Dohvati ime i geolokaciju zgrade
    _loadLocationName();
    _fetchBuildingLocation();

    // Provjeri admin status
    _checkIfLocationAdmin();

    // Dohvati lokaciju korisnika (ako je potrebno za interne oglase)
    _determineUserPosition();

    // Dohvati balans korisnika
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userService.getUserBalance(currentUser.uid).then((value) {
        if (mounted) {
          setState(() {
            _userBalance = value;
          });
        }
      });
    }

    // Inicijalno dohvaćanje oglasa
    _fetchBulletins();

    // Listener za lazy loading
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMoreInternal &&
          !_isLoadingMorePublic &&
          (_hasMoreInternal || _hasMorePublic)) {
        _fetchMoreBulletins();
      }
    });

    // Pokretanje PurchaseService ako je potrebno
    _purchaseService.initialize(_handlePurchase);
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _purchaseService.dispose();
    super.dispose();
  }

  /// Dohvaća trenutnu lokaciju korisnika
  Future<void> _determineUserPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance
                    .translate('location_service_disabled') ??
                'Location services are disabled.',
          ),
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
            content: Text(
              LocalizationService.instance
                      .translate('location_permission_denied') ??
                  'Location permission denied.',
            ),
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.instance
                    .translate('location_permission_denied_forever') ??
                'Location permission permanently denied.',
          ),
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
        _userPosition = position;
      });
    } catch (e) {
      debugPrint("Error fetching user location: $e");
    }
  }

  /// Dohvaća lokaciju same zgrade (za interne oglase i filtriranje javnih oglasa)
  Future<void> _fetchBuildingLocation() async {
    try {
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
          setState(() {
            _buildingLocation = GeoPoint(lat!, lng!);
          });
        } else {
          debugPrint('Error: latitude/longitude or coordinates not available.');
        }
      }
    } catch (e) {
      debugPrint('Error fetching building location: $e');
    }
  }

  /// Dohvaća ime lokacije
  Future<void> _loadLocationName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .get();
      if (doc.exists && doc.data()!.containsKey('name')) {
        setState(() {
          locationName = doc['name'];
        });
      }
    } catch (error) {
      debugPrint('Error loading location name: $error');
    }
  }

  /// Provjerava je li korisnik admin na lokaciji
  Future<void> _checkIfLocationAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      bool adminStatus = await _userService.getLocationAdminStatus(
        currentUser.uid,
        widget.locationId,
      );
      if (!mounted) return;
      setState(() {
        isLocationAdmin = adminStatus;
      });
    }
  }

  /// Postavlja referencu na ispravne kolekcije i dohvaća oglase
  Future<void> _fetchBulletins() async {
    setState(() {
      _bulletins.clear();
      _hasMoreInternal = true;
      _hasMorePublic = true;
      _lastInternalDocument = null;
      _lastPublicDocument = null;
    });

    _internalBulletinsRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('locations')
        .doc(widget.locationId)
        .collection('bulletin_board');

    _publicBulletinsRef = FirebaseFirestore.instance
        .collection('countries')
        .doc(widget.countryId)
        .collection('cities')
        .doc(widget.cityId)
        .collection('public_bullets');

    try {
      if (_selectedAdType == 'Internal') {
        // Dohvati interne oglase
        await _fetchInternalBulletins();
      } else if (_selectedAdType == 'All') {
        // Dohvati i interne i javne oglase paralelno
        await Future.wait([
          _fetchInternalBulletins(),
          _fetchPublicBulletins(),
        ]);

        // Sortiraj oglase prema datumu kreiranja
        _bulletins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint("Error fetching bulletins: $e");
    }
  }

  /// Dohvaća interne oglase
  Future<void> _fetchInternalBulletins() async {
    try {
      Query query = _internalBulletinsRef!
          .where('expired', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        var bulletins = snapshot.docs.map((doc) {
          return Bulletin.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        // Soft delete ako je stariji od 15 dana (interni)
        bulletins = bulletins.map((b) {
          final diff = DateTime.now().difference(b.createdAt).inDays;
          const limitDays = 15;
          if (diff > limitDays) {
            b.expired = true;
            _internalBulletinsRef!.doc(b.id).update({'expired': true});
          }
          return b;
        }).toList();

        setState(() {
          _bulletins.addAll(bulletins);
          _lastInternalDocument = snapshot.docs.last;
          if (snapshot.docs.length < _limit) {
            _hasMoreInternal = false;
          }
        });
      } else {
        setState(() {
          _hasMoreInternal = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching internal bulletins: $e");
    }
  }

  /// Dohvaća javne oglase
  Future<void> _fetchPublicBulletins() async {
    try {
      Query query = _publicBulletinsRef!
          .where('expired', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        var bulletins = snapshot.docs.map((doc) {
          return Bulletin.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        // Soft delete ako je stariji od 15 dana (javni)
        bulletins = bulletins.map((b) {
          final diff = DateTime.now().difference(b.createdAt).inDays;
          const limitDays = 15;
          if (diff > limitDays) {
            b.expired = true;
            _publicBulletinsRef!.doc(b.id).update({'expired': true});
          }
          return b;
        }).toList();

        // Filtriraj javne oglase po radijusu koristeći lokaciju zgrade
        if (_buildingLocation != null) {
          bulletins = bulletins.where((bulletin) {
            final distanceInMeters = Geolocator.distanceBetween(
              _buildingLocation!.latitude,
              _buildingLocation!.longitude,
              bulletin.location.latitude,
              bulletin.location.longitude,
            );
            return distanceInMeters / 1000 <= bulletin.radius;
          }).toList();
        }

        setState(() {
          _bulletins.addAll(bulletins);
          _lastPublicDocument = snapshot.docs.last;
          if (snapshot.docs.length < _limit) {
            _hasMorePublic = false;
          }
        });
      } else {
        setState(() {
          _hasMorePublic = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching public bulletins: $e");
    }
  }

  /// Dohvaća dodatne oglase za lazy loading
  Future<void> _fetchMoreBulletins() async {
    if (_selectedAdType == 'Internal') {
      if (!_hasMoreInternal ||
          _lastInternalDocument == null ||
          _internalBulletinsRef == null) {
        return;
      }
      await _fetchMoreInternalBulletins();
    } else if (_selectedAdType == 'All') {
      if (_hasMoreInternal && _lastInternalDocument != null) {
        await _fetchMoreInternalBulletins();
      }
      if (_hasMorePublic && _lastPublicDocument != null) {
        await _fetchMorePublicBulletins();
      }
      setState(() {
        _bulletins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
  }

  /// Dohvaća dodatne interne oglase
  Future<void> _fetchMoreInternalBulletins() async {
    if (_isLoadingMoreInternal) return;
    setState(() {
      _isLoadingMoreInternal = true;
    });

    try {
      Query query = _internalBulletinsRef!
          .where('expired', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastInternalDocument!)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        var bulletins = snapshot.docs.map((doc) {
          return Bulletin.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        bulletins = bulletins.map((b) {
          final diff = DateTime.now().difference(b.createdAt).inDays;
          const limitDays = 15;
          if (diff > limitDays) {
            b.expired = true;
            _internalBulletinsRef!.doc(b.id).update({'expired': true});
          }
          return b;
        }).toList();

        setState(() {
          _bulletins.addAll(bulletins);
          _lastInternalDocument = snapshot.docs.last;
          if (snapshot.docs.length < _limit) {
            _hasMoreInternal = false;
          }
        });
      } else {
        setState(() {
          _hasMoreInternal = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching more internal bulletins: $e");
    }

    setState(() {
      _isLoadingMoreInternal = false;
    });
  }

  /// Dohvaća dodatne javne oglase
  Future<void> _fetchMorePublicBulletins() async {
    if (_isLoadingMorePublic) return;
    setState(() {
      _isLoadingMorePublic = true;
    });

    try {
      Query query = _publicBulletinsRef!
          .where('expired', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastPublicDocument!)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        var bulletins = snapshot.docs.map((doc) {
          return Bulletin.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();

        bulletins = bulletins.map((b) {
          final diff = DateTime.now().difference(b.createdAt).inDays;
          const limitDays = 15;
          if (diff > limitDays) {
            b.expired = true;
            _publicBulletinsRef!.doc(b.id).update({'expired': true});
          }
          return b;
        }).toList();

        if (_buildingLocation != null) {
          bulletins = bulletins.where((bulletin) {
            final distanceInMeters = Geolocator.distanceBetween(
              _buildingLocation!.latitude,
              _buildingLocation!.longitude,
              bulletin.location.latitude,
              bulletin.location.longitude,
            );
            return distanceInMeters / 1000 <= bulletin.radius;
          }).toList();
        }

        setState(() {
          _bulletins.addAll(bulletins);
          _lastPublicDocument = snapshot.docs.last;
          if (snapshot.docs.length < _limit) {
            _hasMorePublic = false;
          }
        });
      } else {
        setState(() {
          _hasMorePublic = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching more public bulletins: $e");
    }

    setState(() {
      _isLoadingMorePublic = false;
    });
  }

  /// Otvara ekran za dodavanje oglasa
  void _showAddBulletinForm() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (ctx) => AddBulletinScreen(
          username: widget.username,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          onSave: (bulletin) async {
            if (!mounted) return;
            setState(() {
              _bulletins.insert(0, bulletin);
            });
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              double newBalance =
                  await _userService.getUserBalance(currentUser.uid);
              setState(() {
                _userBalance = newBalance;
              });
            }
          },
        ),
      ),
    )
        .then((_) async {
      _fetchBulletins();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        double newBalance = await _userService.getUserBalance(currentUser.uid);
        if (mounted) {
          setState(() {
            _userBalance = newBalance;
          });
        }
      }
    });
  }

  /// Briše bulletin
  void _deleteBulletin(int index) async {
    try {
      final bulletin = _bulletins[index];
      if (bulletin.isInternal) {
        await _internalBulletinsRef!.doc(bulletin.id).delete();
      } else {
        await _publicBulletinsRef!.doc(bulletin.id).delete();
      }
      setState(() {
        _bulletins.removeAt(index);
      });
    } catch (error) {
      debugPrint('Error deleting bulletin: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              LocalizationService.instance.translate('delete_failed') ??
                  'Deletion failed.'),
        ),
      );
    }
  }

  /// Dijeljenje bulletina (tekstualno)
  Future<void> _shareBulletin(Bulletin bulletin) async {
    final String content = '''
${LocalizationService.instance.translate('shared_from_conexa') ?? 'Shared from Conexa (conexa.life)'}

${bulletin.title}

${bulletin.description}
''';
    await Share.share(content);
  }

  /// Preuzimanje bulletina kao txt
  Future<void> _downloadBulletin(Bulletin bulletin) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sanitizedTitle =
          bulletin.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${directory.path}/$sanitizedTitle.txt');
      await file.writeAsString('${bulletin.title}\n\n${bulletin.description}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${LocalizationService.instance.translate('downloaded') ?? 'Downloaded'} ${bulletin.title}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${LocalizationService.instance.translate('download_failed') ?? 'Failed to download'} ${bulletin.title}',
          ),
        ),
      );
    }
  }

  /// Dodavanje komentara (na popisu bez ulaska u fullscreen)
  Future<void> _commentOnBulletin(int index, Bulletin bulletin) async {
    final TextEditingController commentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        final localization = LocalizationService.instance;
        return AlertDialog(
          title: Text(
              '${localization.translate('comment_on') ?? 'Comment on'} ${bulletin.title}'),
          content: TextField(
            controller: commentController,
            decoration: InputDecoration(
                hintText: localization.translate('enter_comment') ??
                    'Enter your comment'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localization.translate('cancel') ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () {
                final comment = commentController.text;
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(localization.translate('empty_comment') ??
                            'Comment cannot be empty')),
                  );
                  return;
                }
                final newComment = {
                  'text': comment,
                  'author': widget.username,
                  'time': DateTime.now().toIso8601String(),
                };
                setState(() {
                  bulletin.comments = List.from(bulletin.comments)
                    ..add(newComment);
                });
                if (bulletin.isInternal) {
                  _internalBulletinsRef!.doc(bulletin.id).update({
                    'comments': bulletin.comments,
                  });
                } else {
                  _publicBulletinsRef!.doc(bulletin.id).update({
                    'comments': bulletin.comments,
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text(localization.translate('submit') ?? 'Submit'),
            ),
          ],
        );
      },
    );
  }

  /// Like bulletina (na popisu)
  void _likeBulletin(int index) {
    if (_bulletins[index].userLiked) return;

    setState(() {
      _bulletins[index].likes++;
      _bulletins[index].userLiked = true;
      if (_bulletins[index].userDisliked) {
        _bulletins[index].dislikes--;
        _bulletins[index].userDisliked = false;
      }
    });

    final bulletin = _bulletins[index];
    Map<String, dynamic> updateData = {
      'likes': bulletin.likes,
      'userLiked': true,
      'dislikes': bulletin.dislikes,
      'userDisliked': bulletin.userDisliked,
    };

    if (bulletin.isInternal) {
      _internalBulletinsRef!.doc(bulletin.id).update(updateData);
    } else {
      _publicBulletinsRef!.doc(bulletin.id).update(updateData);
    }
  }

  /// Dislike bulletina (na popisu)
  void _dislikeBulletin(int index) {
    if (_bulletins[index].userDisliked) return;

    setState(() {
      _bulletins[index].dislikes++;
      _bulletins[index].userDisliked = true;
      if (_bulletins[index].userLiked) {
        _bulletins[index].likes--;
        _bulletins[index].userLiked = false;
      }
    });

    final bulletin = _bulletins[index];
    Map<String, dynamic> updateData = {
      'dislikes': bulletin.dislikes,
      'userDisliked': true,
      'likes': bulletin.likes,
      'userLiked': bulletin.userLiked,
    };

    if (bulletin.isInternal) {
      _internalBulletinsRef!.doc(bulletin.id).update(updateData);
    } else {
      _publicBulletinsRef!.doc(bulletin.id).update(updateData);
    }
  }

  /// Otvaranje bulletina u fullscreen modu
  void _openBulletin(Bulletin bulletin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenBulletin(
          bulletin: bulletin,
          countryId: widget.countryId,
          cityId: widget.cityId,
          locationId: widget.locationId,
          username: widget.username, // Dodano: prosljeđivanje username-a
          onLike: bulletin.userLiked
              ? () {}
              : () => _likeBulletin(_bulletins.indexOf(bulletin)),
          onDislike: bulletin.userDisliked
              ? () {}
              : () => _dislikeBulletin(_bulletins.indexOf(bulletin)),
          onComment: () =>
              _commentOnBulletin(_bulletins.indexOf(bulletin), bulletin),
          onShare: () => _shareBulletin(bulletin),
          onDownload: () => _downloadBulletin(bulletin),
        ),
      ),
    );
  }

  /// Handler za kupnju
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

  /// Dohvaća popis proizvoda
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.white,
        title: Text(
          locationName,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _showAddBulletinForm,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              localizationService.translate('add_bulletin') ?? 'Add Bulletin',
              style: const TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            width: double.infinity,
            color: Colors.yellow[700],
            child: Center(
              child: Text(
                localizationService.translate('bulletin_board') ??
                    'Bulletin Board',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Divider(
            height: 0,
            thickness: 2,
            color: Colors.grey,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizationService.translate('select_ad_type') ??
                        'Select ad type:',
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
                    });
                    _fetchBulletins();
                  },
                  isExpanded: true,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _bulletins.isEmpty
                ? Center(
                    child: Text(
                      localizationService.translate('no_bulletins_found') ??
                          'No bulletins available',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _bulletins.length +
                        (_isLoadingMoreInternal || _isLoadingMorePublic
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == _bulletins.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final bulletin = _bulletins[index];
                      final isCreator = bulletin.createdBy == currentUser?.uid;
                      final canDelete = isCreator || isLocationAdmin;

                      return BulletinListItem(
                        bulletin: bulletin,
                        onDelete:
                            canDelete ? () => _deleteBulletin(index) : null,
                        onLike: bulletin.userLiked
                            ? null
                            : () => _likeBulletin(index),
                        onDislike: bulletin.userDisliked
                            ? null
                            : () => _dislikeBulletin(index),
                        onComment: () => _commentOnBulletin(index, bulletin),
                        onShare: () => _shareBulletin(bulletin),
                        onDownload: () => _downloadBulletin(bulletin),
                        onTap: () => _openBulletin(bulletin),
                        canEdit: canDelete,
                        showLimitedDescription: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
