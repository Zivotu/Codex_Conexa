// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import "package:font_awesome_flutter/font_awesome_flutter.dart";
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';
import '../services/localization_service.dart';
import 'register_screen.dart';
import 'user_locations_screen.dart';
import 'voxpopuli.dart'; // pretpostavljamo da ovaj fajl sadrži VoxPopuliScreen
import 'onboarding_screen.dart';
import 'affiliate_intro_screen.dart';

class LanguageItem {
  final String code;
  final String display;

  const LanguageItem(this.code, this.display);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final Logger _logger = Logger();
  String _selectedLanguage = 'hr'; // Defaultni jezik

  late UserService _userService;
  late FCMService _fcmService;

  // Izvučena lista jezika za Dropdown
  final List<LanguageItem> _languageItems = const [
    LanguageItem('en', '🇬🇧 English'),
    LanguageItem('ar', '🇸🇦 العربية'),
    LanguageItem('bn', '🇧🇩 বাংলা'),
    LanguageItem('bs', '🇧🇦 Bosanski'),
    LanguageItem('da', '🇩🇰 Dansk'),
    LanguageItem('de', '🇩🇪 Deutsch'),
    LanguageItem('es', '🇪🇸 Español'),
    LanguageItem('fa', '🇮🇷 فارسی'),
    LanguageItem('fi', '🇫🇮 Suomi'),
    LanguageItem('fr', '🇫🇷 Français'),
    LanguageItem('hi', '🇮🇳 हिन्दी'),
    LanguageItem('hr', '🇭🇷 Hrvatski'),
    LanguageItem('hu', '🇭🇺 Magyar'),
    LanguageItem('id', '🇮🇩 Bahasa Indonesia'),
    LanguageItem('is', '🇮🇸 Íslenska'),
    LanguageItem('it', '🇮🇹 Italiano'),
    LanguageItem('ja', '🇯🇵 日本語'),
    LanguageItem('ko', '🇰🇷 한국어'),
    LanguageItem('nl', '🇳🇱 Nederlands'),
    LanguageItem('no', '🇳🇴 Norsk'),
    LanguageItem('pl', '🇵🇱 Polski'),
    LanguageItem('pt', '🇵🇹 Português'),
    LanguageItem('ro', '🇷🇴 Română'),
    LanguageItem('ru', '🇷🇺 Русский'),
    LanguageItem('sl', '🇸🇮 Slovensko'),
    LanguageItem('sr', '🇷🇸 Srpski'),
    LanguageItem('sv', '🇸🇪 Svenska'),
    LanguageItem('th', '🇹🇭 ไทย'),
    LanguageItem('tr', '🇹🇷 Türkçe'),
    LanguageItem('vi', '🇻🇳 Tiếng Việt'),
  ];

  // Varijabla koja označava da li je onboarding provjeren
  bool _didCheckOnboarding = false;

  @override
  void initState() {
    super.initState();
    _userService = GetIt.I<UserService>();
    _fcmService = GetIt.I<FCMService>();
    _loadSavedLanguage();
    _checkOnboarding();
  }

  Future<void> _loadSavedLanguage() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    String currentLanguage = localizationService.currentLanguage;
    setState(() {
      _selectedLanguage = currentLanguage;
    });
  }

  Future<void> _changeLanguage(String languageCode) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    await localizationService.loadLanguage(languageCode);
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    bool done = prefs.getBool('onboarding_completed') ?? false;

    if (!done) {
      // Ako onboarding nije završen, pokrećemo ga nakon prvog framea
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(
              onFinish: () async {
                // npr. kad user dođe do zadnje stranice onboarding-a:
                // Ovdje možete postaviti SharedPreferences, npr.:
                // final prefs = await SharedPreferences.getInstance();
                // prefs.setBool('onboarding_completed', true);

                Navigator.pop(context); // vraća se na LoginScreen
              },
              onSkip: () async {
                // npr. kada user klikne “Skip”:
                // final prefs = await SharedPreferences.getInstance();
                // prefs.setBool('onboarding_completed', true);

                Navigator.pop(context);
              },
            ),
          ),
        );
      });
    }
    setState(() {
      _didCheckOnboarding = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    FocusScope.of(context).unfocus();

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        final userData = await _userService.getUserDocument(user);
        if (userData != null) {
          await _fcmService.handleUserLogin(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => UserLocationsScreen(
                username: userData['username'] ??
                    Provider.of<LocalizationService>(context, listen: false)
                        .translate('default_user'),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<LocalizationService>(context, listen: false)
                    .translate('failed_to_retrieve_user_data'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${Provider.of<LocalizationService>(context, listen: false).translate('failed_to_login')} $e',
          ),
        ),
      );
      _logger.e("Login failed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                .translate('please_enter_email'),
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                .translate('password_reset_link_sent'),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${Provider.of<LocalizationService>(context, listen: false).translate('error_sending_email')} $e',
          ),
        ),
      );
      _logger.e("Password reset failed: $e");
    }
  }

  // Helper funkcija za otvaranje URL-ova.
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  // Otvara ekran za pomoć ili jednostavan dialog ako korisnik nije ulogiran.
  void _openHelp() {
    if (FirebaseAuth.instance.currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const VoxPopuliScreen()),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const SimpleHelpDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Pozadinska slika
            Positioned.fill(
              child: Image.asset(
                'assets/images/conexa_bg_1.png',
                fit: BoxFit.cover,
              ),
            ),
            // Plavi gradient preko slike radi čitljivosti
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xFFB3E5FC),
                      Color(0xFF0288D1),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Društveni linkovi na bijelo transparentnoj pozadini
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.linkedin),
                            tooltip: 'LinkedIn',
                            onPressed: () => _launchURL(
                                "https://www.linkedin.com/company/conexalife"),
                          ),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.twitter),
                            tooltip: 'Twitter',
                            onPressed: () =>
                                _launchURL("https://x.com/Conexa_App"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Izbornik jezika
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          onChanged: (String? newLanguage) {
                            if (newLanguage != null) {
                              _changeLanguage(newLanguage);
                            }
                          },
                          items: _languageItems
                              .map(
                                (lang) => DropdownMenuItem<String>(
                                  value: lang.code,
                                  child: Text(
                                    lang.display,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          dropdownColor: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Polje za email
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('email'),
                        labelStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black54,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    // Polje za lozinku
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: localizationService.translate('password'),
                        labelStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black54,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : Text(localizationService.translate('login')),
                    ),
                    const Spacer(),

                    // Register button
                    ElevatedButton(
                      onPressed: _navigateToRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        localizationService.translate('register'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Forgot password
                    TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        localizationService.translate('forgot_password'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // "Zatraži pomoć" button
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _openHelp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text(
                            localizationService.translate('request_help'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizationService.translate('prompt_response'),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // "Watch VIDEO" link – otvara YouTube Shorts
                    TextButton(
                      onPressed: () =>
                          _launchURL("https://youtube.com/shorts/82Nsgn200iM"),
                      child: Text(
                        localizationService.translate('watch_video'),
                        style: const TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment
                          .center, // ili Alignment.centerLeft/centerRight
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                              255, 0, 107, 150), // tirkizna pozadina
                          foregroundColor: Colors.white, // boja teksta
                          minimumSize:
                              Size(0, 0), // makni defaultnu minimalnu širinu
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                16, // po želji: više/manje razmaka lijevo/desno
                            vertical: 12, // visina gumba
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AffiliateIntroScreen()),
                          );
                        },
                        child: Text(
                          localizationService.translate('affiliate') ??
                              'Partner',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Jednostavan dialog za unos poruke (koristi se ako korisnik nije ulogiran)
class SimpleHelpDialog extends StatefulWidget {
  const SimpleHelpDialog({super.key});

  @override
  _SimpleHelpDialogState createState() => _SimpleHelpDialogState();
}

class _SimpleHelpDialogState extends State<SimpleHelpDialog> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _isSending = false;
  final Logger _logger = Logger();

  Future<void> _sendFeedback() async {
    final String message = _messageController.text;
    final String? name =
        _nameController.text.isNotEmpty ? _nameController.text : null;
    final String? contact =
        _contactController.text.isNotEmpty ? _contactController.text : null;

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                .translate('message_cannot_be_empty'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await FirebaseFirestore.instance.collection('voxpopuli_hr').add({
        'message': message,
        'name': name,
        'contact': contact,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'profilePic': FirebaseAuth.instance.currentUser?.photoURL,
      });

      _messageController.clear();
      _nameController.clear();
      _contactController.clear();

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            Provider.of<LocalizationService>(context, listen: false)
                .translate('thank_you'),
          ),
          content: Text(
            Provider.of<LocalizationService>(context, listen: false)
                .translate('message_sent_successfully'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${Provider.of<LocalizationService>(context, listen: false).translate('error_sending_email')} $e',
          ),
        ),
      );
      _logger.e("Feedback send failed: $e");
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return AlertDialog(
      title: Text(localizationService.translate('request_help')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: localizationService.translate('enter_your_message'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: localizationService.translate('name_optional'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: localizationService.translate('contact_optional'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : _sendFeedback,
          child: _isSending
              ? const CircularProgressIndicator()
              : Text(localizationService.translate('send')),
        ),
      ],
    );
  }
}

// Placeholder za VideoScreen
class VideoScreen extends StatelessWidget {
  const VideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('video')),
      ),
      body: Center(
        child: Text(localizationService.translate('video_placeholder')),
      ),
    );
  }
}
