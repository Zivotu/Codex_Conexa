import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Za TapGestureRecognizer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../models/chat_model.dart';
import '../services/location_service.dart' as loc_service;
import '../services/user_service.dart' as user_service;
import '../services/localization_service.dart';
import 'infos/info_chat.dart';

final Logger _logger = Logger();

class GroupChatPage extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;
  final ImagePicker _picker = ImagePicker();

  GroupChatPage({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  GroupChatPageState createState() => GroupChatPageState();
}

class GroupChatPageState extends State<GroupChatPage> {
  final loc_service.LocationService locationService =
      loc_service.LocationService();
  final user_service.UserService userService = user_service.UserService();

  // Podaci o lokaciji i korisniku
  String? locationName = '';
  String? userImageUrl = '';
  String displayName = '';

  // Provjera offline statusa
  bool _isOffline = false;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _logger.d("Init GroupChatPage with:");
    _logger.d("Country ID: ${widget.countryId}");
    _logger.d("City ID: ${widget.cityId}");
    _logger.d("Location ID: ${widget.locationId}");

    // Slušanje promjena konekcije pomoću "omatanja" događaja
    Stream<dynamic> connectivityStream = Connectivity().onConnectivityChanged;
    _connectivitySubscription = connectivityStream.listen((dynamic event) {
      if (event is ConnectivityResult) {
        setState(() {
          _isOffline = event == ConnectivityResult.none;
        });
      } else if (event is List<ConnectivityResult>) {
        setState(() {
          _isOffline = event.contains(ConnectivityResult.none);
        });
      }
    });

    // Prikaz onboarding ekrana ako je potrebno
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOnboardingScreen(context);
    });

    // Dohvati naziv lokacije
    _fetchLocationName();
    // Učitaj osnovne podatke o korisniku
    _loadUserData();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Prikazuje onboarding ekran samo prvi put
  Future<void> _showOnboardingScreen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool shouldShow = prefs.getBool('show_chat_onboarding') ?? true;

    if (shouldShow) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ChatOnboardingScreen(),
        ),
      );
      await prefs.setBool('show_chat_onboarding', false);
    }
  }

  /// Dohvaća profil trenutnog korisnika iz kolekcije 'users'
  Future<void> _fetchUserProfile() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();

    if (userDoc.exists && mounted) {
      setState(() {
        displayName = userDoc.data()?['username'] ?? 'Unknown User';
        userImageUrl = userDoc.data()?['profileImageUrl'] ??
            'assets/images/default_user.png';
      });
    } else {
      _logger.w('User dokument nije pronađen.');
    }
  }

  /// Dohvaća naziv lokacije iz Firestore-a
  Future<void> _fetchLocationName() async {
    if (widget.countryId.isNotEmpty &&
        widget.cityId.isNotEmpty &&
        widget.locationId.isNotEmpty) {
      final locationDoc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .get();

      if (locationDoc.exists) {
        setState(() {
          locationName = locationDoc.data()?['name'] ?? 'Unnamed Location';
        });
      } else {
        _logger.w("Location dokument ne postoji.");
      }
    } else {
      _logger.e("Neispravni identifikatori lokacije.");
    }
  }

  /// Učitava osnovne podatke korisnika (displayName i userImageUrl)
  Future<void> _loadUserData() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          displayName = userDoc.data()?['username'] ?? 'User';
          userImageUrl = userDoc.data()?['profileImageUrl']?.trim() ??
              'assets/images/default_user.png';
        });
      } else {
        _logger.w("User dokument nije pronađen u kolekciji 'users'.");
      }
    } else {
      _logger.w("Korisnik nije prijavljen.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    // Koristimo lokalnu varijablu safeUserImageUrl
    final safeUserImageUrl = userImageUrl ?? '';

    _logger.d("Building GroupChatPage with:");
    _logger.d("Country ID: ${widget.countryId}");
    _logger.d("City ID: ${widget.cityId}");
    _logger.d("Location ID: ${widget.locationId}");

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        title: Text(
          (locationName ?? '').isNotEmpty
              ? locationName!
              : localizationService.translate('unnamedLocation') ??
                  'Unnamed Location',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: safeUserImageUrl.isNotEmpty
                      ? (safeUserImageUrl.startsWith('http')
                          ? NetworkImage(safeUserImageUrl)
                          : AssetImage(safeUserImageUrl) as ImageProvider)
                      : const AssetImage('assets/images/default_user.png'),
                  onBackgroundImageError: (_, __) {
                    _logger.e('Greška prilikom učitavanja profilne slike.');
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  displayName.isNotEmpty ? displayName : 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        // Gradient pozadina za moderan izgled
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color.fromARGB(255, 255, 255, 255)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.red,
                padding: const EdgeInsets.all(8.0),
                child: const Text(
                  'Offline',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            // Prikaz poruka
            Expanded(
              child: StreamBuilder(
                stream: locationService.getChatStream(
                    widget.countryId, widget.cityId, widget.locationId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _logger
                        .e('Greška pri učitavanju poruka: ${snapshot.error}');
                    return Center(
                      child: Text(
                        localizationService.translate('errorLoadingMessages') ??
                            'Greška pri učitavanju poruka.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    _logger.d('Još nema podataka.');
                    return const Center(child: CircularProgressIndicator());
                  }

                  var messages = (snapshot.data as QuerySnapshot).docs;
                  _logger
                      .d('Preuzeto ${messages.length} poruka iz Firestore-a.');

                  if (messages.isEmpty) {
                    _logger.w('Nema poruka za ovaj chat.');
                    return Center(
                      child: Text(
                        localizationService.translate('noMessages') ??
                            'Nema poruka.',
                      ),
                    );
                  }

                  var chatMessages = messages
                      .map((doc) => ChatModel.fromJson(
                          doc.data() as Map<String, dynamic>))
                      .toList();

                  return ListView.builder(
                    reverse: true,
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      var message = chatMessages[index];
                      _updateViewedBy(message);
                      return _buildMessageItem(
                          context, message, localizationService);
                    },
                  );
                },
              ),
            ),
            // Widget za unos poruke
            _buildMessageInput(context, localizationService),
          ],
        ),
      ),
    );
  }

  /// Ažurira polje `viewedBy` tako da uključuje trenutnog korisnika (ako već nije)
  Future<void> _updateViewedBy(ChatModel message) async {
    var userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    var messageRef = locationService.getChatMessageRef(
        widget.countryId, widget.cityId, widget.locationId, message.id);

    if (!message.viewedBy.contains(userId)) {
      await messageRef.update({
        'viewedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  /// Gradi widget za unos nove poruke
  Widget _buildMessageInput(
      BuildContext context, LocalizationService localizationService) {
    TextEditingController controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.teal),
            onPressed: () async {
              XFile? pickedFile =
                  await widget._picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                if (!mounted) return;
                await _sendMessageWithLocalImage(
                    controller.text, File(pickedFile.path));
                controller.clear();
              }
            },
            tooltip: localizationService.translate('pickFromGallery') ??
                'Odaberi iz galerije',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.teal),
            onPressed: () async {
              XFile? pickedFile =
                  await widget._picker.pickImage(source: ImageSource.camera);
              if (pickedFile != null) {
                if (!mounted) return;
                await _sendMessageWithLocalImage(
                    controller.text, File(pickedFile.path));
                controller.clear();
              }
            },
            tooltip: localizationService.translate('takePhoto') ?? 'Slikaj',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: localizationService.translate('typeMessage') ??
                    'Unesite poruku',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.teal),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _sendMessage(controller.text, '');
                controller.clear();
              }
            },
            tooltip: localizationService.translate('send') ?? 'Pošalji',
          ),
        ],
      ),
    );
  }

  /// Gradi svaki pojedinačni chat item (poruku)
  Widget _buildMessageItem(BuildContext context, ChatModel message,
      LocalizationService localizationService) {
    bool isMe = message.userId == FirebaseAuth.instance.currentUser?.uid;

    String userName = (message.user.isNotEmpty) ? message.user : 'Unknown User';
    // Ako je profileImageUrl null, postavljamo default vrijednost
    final msgUserImageUrl = (message.profileImageUrl ?? '').isNotEmpty
        ? message.profileImageUrl
        : 'assets/images/default_user.png';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  backgroundImage: msgUserImageUrl.startsWith('http')
                      ? CachedNetworkImageProvider(msgUserImageUrl)
                      : AssetImage(msgUserImageUrl) as ImageProvider,
                  onBackgroundImageError: (_, __) {
                    _logger.e('Greška prilikom učitavanja profilne slike.');
                  },
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      DateFormat('d.M.yyyy. - EEEE - HH:mm')
                          .format(message.createdAt.toDate()),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: () =>
                          _showFullScreenImage(context, message.imageUrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color.fromARGB(255, 220, 228, 243)
                              : Colors.white,
                          borderRadius: isMe
                              ? const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                )
                              : const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.imageUrl.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                  maxHeight: 200,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: message.imageUrl,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (message.repliesTo != null)
                              FutureBuilder<DocumentSnapshot>(
                                future: locationService.getChatMessage(
                                  widget.countryId,
                                  widget.cityId,
                                  widget.locationId,
                                  message.repliesTo!,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  }
                                  var repliedMessage = snapshot.data?.data()
                                      as Map<String, dynamic>?;
                                  return repliedMessage != null
                                      ? Container(
                                          padding: const EdgeInsets.all(8.0),
                                          margin: const EdgeInsets.only(
                                              bottom: 8.0),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            repliedMessage['text'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                            const SizedBox(height: 5),
                            SelectableText.rich(
                              _buildTextSpan(message.text),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundImage: msgUserImageUrl.startsWith('http')
                      ? CachedNetworkImageProvider(msgUserImageUrl)
                      : AssetImage(msgUserImageUrl) as ImageProvider,
                  onBackgroundImageError: (_, __) {
                    _logger.e('Greška prilikom učitavanja profilne slike.');
                  },
                ),
              ],
            ],
          ),
          Row(
            children: [
              if (!isMe) const SizedBox(width: 48),
              if (isMe) Expanded(child: Container()),
              if (!isMe)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.visibility,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${message.viewedBy.length}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${message.viewedBy.length}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              IconButton(
                icon: Icon(
                  message.likedBy
                          .contains(FirebaseAuth.instance.currentUser?.uid)
                      ? Icons.thumb_up
                      : Icons.thumb_up_off_alt,
                  color: message.likedBy
                          .contains(FirebaseAuth.instance.currentUser?.uid)
                      ? Colors.teal
                      : Colors.grey,
                ),
                onPressed: () => _likeMessage(message),
                tooltip: localizationService.translate('like') ?? 'Like',
              ),
              Text('${message.likes}'),
              IconButton(
                icon: Icon(
                  message.dislikedBy
                          .contains(FirebaseAuth.instance.currentUser?.uid)
                      ? Icons.thumb_down
                      : Icons.thumb_down_off_alt,
                  color: message.dislikedBy
                          .contains(FirebaseAuth.instance.currentUser?.uid)
                      ? Colors.red
                      : Colors.grey,
                ),
                onPressed: () => _dislikeMessage(message),
                tooltip: localizationService.translate('dislike') ?? 'Dislike',
              ),
              Text('${message.dislikes}'),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.teal),
                onPressed: () => _shareMessage(context, message),
                tooltip: localizationService.translate('share') ?? 'Share',
              ),
              Text('${message.shares}'),
              IconButton(
                icon: const Icon(Icons.reply, color: Colors.teal),
                onPressed: () async {
                  String? replyText;
                  replyText = await showDialog<String>(
                    context: context,
                    builder: (context) {
                      TextEditingController replyController =
                          TextEditingController();
                      return AlertDialog(
                        title: Text(
                          localizationService.translate('replyToMessage') ??
                              'Odgovori na poruku',
                        ),
                        content: TextField(
                          controller: replyController,
                          onChanged: (value) {
                            replyText = value;
                          },
                          decoration: InputDecoration(
                            hintText: localizationService
                                    .translate('typeYourReply') ??
                                'Upišite odgovor',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, replyController.text),
                            child: Text(
                              localizationService.translate('send') ??
                                  'Pošalji',
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (replyText?.isNotEmpty ?? false) {
                    if (!mounted) return;
                    await _replyMessage(message, replyText!);
                  }
                },
                tooltip: localizationService.translate('reply') ?? 'Odgovori',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pomoćna funkcija za kreiranje TextSpan-a s klikabilnim linkovima
  TextSpan _buildTextSpan(String text) {
    final RegExp urlRegExp = RegExp(
      r'((https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-.,@?^=%&:/~+#]*)?)',
      caseSensitive: false,
    );

    final List<RegExpMatch> matches = urlRegExp.allMatches(text).toList();
    if (matches.isEmpty) {
      return TextSpan(text: text);
    }

    List<TextSpan> children = [];
    int start = 0;

    for (final match in matches) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }

      String url = match.group(0) ?? '';
      if (!url.startsWith('http')) {
        url = 'http://$url';
      }

      children.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final Uri uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              _logger.e('Ne mogu otvoriti $url');
            }
          },
      ));

      start = match.end;
    }

    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(children: children);
  }

  /// Šalje običnu poruku
  Future<void> _sendMessage(String message, String imageUrl) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final safeUserImageUrl = userImageUrl ?? '';
      String profileImg = safeUserImageUrl.isNotEmpty
          ? safeUserImageUrl
          : 'assets/images/default_user.png';

      var chatRef = locationService.getNewChatRef(
          widget.countryId, widget.cityId, widget.locationId);

      var chatModel = ChatModel(
        id: chatRef.id,
        text: message,
        imageUrl: imageUrl,
        createdAt: Timestamp.now(),
        user: displayName.isNotEmpty ? displayName : 'Unknown User',
        userId: user.uid,
        profileImageUrl: profileImg,
        likes: 0,
        dislikes: 0,
        shares: 0,
        viewedBy: [],
        likedBy: [],
        dislikedBy: [],
        repliesTo: null,
      );

      await chatRef.set(chatModel.toJson());
    }
  }

  /// Šalje poruku s lokalno odabranom slikom
  Future<void> _sendMessageWithLocalImage(
      String message, File imageFile) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final safeUserImageUrl = userImageUrl ?? '';
        String profileImg = safeUserImageUrl.isNotEmpty
            ? safeUserImageUrl
            : 'assets/images/default_user.png';

        var chatRef = locationService.getNewChatRef(
            widget.countryId, widget.cityId, widget.locationId);

        var chatModel = ChatModel(
          id: chatRef.id,
          text: message,
          imageUrl: '',
          createdAt: Timestamp.now(),
          user: displayName.isNotEmpty ? displayName : 'Unknown User',
          userId: user.uid,
          profileImageUrl: profileImg,
          likes: 0,
          dislikes: 0,
          shares: 0,
          viewedBy: [],
          likedBy: [],
          dislikedBy: [],
          repliesTo: null,
        );

        await chatRef.set(chatModel.toJson());
        String imageUrl = await _uploadImage(imageFile);
        await chatRef.update({'imageUrl': imageUrl});
      }
    } catch (e) {
      _logger.e("Greška pri slanju slike: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri slanju slike: $e')),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  /// Uploada sliku na Firebase Storage i vraća URL
  Future<String> _uploadImage(File image) async {
    String fileName = path.basename(image.path);
    UploadTask uploadTask =
        FirebaseStorage.instance.ref('chat_images/$fileName').putFile(image);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Prikazuje sliku preko cijelog ekrana
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);

    if (imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            title: Text(localizationService.translate('image') ?? 'Image'),
          ),
          body: Center(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      ),
    );
  }

  /// "Like"-a poruku
  void _likeMessage(ChatModel message) {
    var userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      var messageRef = locationService.getChatMessageRef(
          widget.countryId, widget.cityId, widget.locationId, message.id);

      if (message.likedBy.contains(userId)) {
        messageRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        messageRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likes': FieldValue.increment(1),
        });
      }
    }
  }

  /// "Dislike"-a poruku
  void _dislikeMessage(ChatModel message) {
    var userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      var messageRef = locationService.getChatMessageRef(
          widget.countryId, widget.cityId, widget.locationId, message.id);

      if (message.dislikedBy.contains(userId)) {
        messageRef.update({
          'dislikedBy': FieldValue.arrayRemove([userId]),
          'dislikes': FieldValue.increment(-1),
        });
      } else {
        messageRef.update({
          'dislikedBy': FieldValue.arrayUnion([userId]),
          'dislikes': FieldValue.increment(1),
        });
      }
    }
  }

  /// Dijeli poruku
  void _shareMessage(BuildContext context, ChatModel message) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final String text =
        message.text.isEmpty ? ' ' : '${message.text}\n\nconexa.life';
    final List<XFile> attachments = [];

    if (message.imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(message.imageUrl));
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, 'shared_image.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        attachments.add(XFile(file.path));
      } catch (e) {
        _logger.e('Greška pri preuzimanju slike: $e');
      }
    }

    if (attachments.isNotEmpty) {
      await Share.shareXFiles(attachments, text: text);
    } else {
      await Share.share(text);
    }

    var messageRef = locationService.getChatMessageRef(
        widget.countryId, widget.cityId, widget.locationId, message.id);

    messageRef.update({'shares': FieldValue.increment(1)});
  }

  /// Odgovara na postojeću poruku
  Future<void> _replyMessage(ChatModel chat, String replyText) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final safeUserImageUrl = userImageUrl ?? '';
      String profileImg = safeUserImageUrl.isNotEmpty
          ? safeUserImageUrl
          : 'assets/images/default_user.png';

      var chatRef = locationService.getNewChatRef(
          widget.countryId, widget.cityId, widget.locationId);

      var chatModel = ChatModel(
        id: chatRef.id,
        text: replyText,
        imageUrl: '',
        createdAt: Timestamp.now(),
        user: displayName.isNotEmpty ? displayName : 'Current User',
        userId: user.uid,
        profileImageUrl: profileImg,
        likes: 0,
        dislikes: 0,
        shares: 0,
        viewedBy: [],
        likedBy: [],
        dislikedBy: [],
        repliesTo: chat.id,
      );

      if (!mounted) return;
      await chatRef.set(chatModel.toJson());
    }
  }
}
