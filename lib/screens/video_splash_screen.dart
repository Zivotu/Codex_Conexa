import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart' as mainFile;
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'user_locations_screen.dart';

/// VideoSplashScreen prikazuje uvodni video; kad se video završi:
/// • Ako je korisnik logiran → preusmjerava na UserLocationsScreen;
/// • Ako nije, provjerava da li je onboarding završen:
///    – Ako je, ide na LoginScreen;
///    – Inače, pokreće OnboardingScreen.
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _navigationTriggered = false;
  final Logger _logger = Logger();

  late VoidCallback _videoListener;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/images/conexa_intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });

    _videoListener = () async {
      if (!mounted || _navigationTriggered) return;

      if (_controller.value.position >= _controller.value.duration) {
        _logger.d(">>> Video finished playing => start navigation checks.");
        _navigationTriggered = true;

        // 1. Provjeri update (ako je potrebno)
        bool updateChosen = await mainFile.checkForUpdate(context);
        if (!mounted) return;
        if (updateChosen) {
          return;
        }

        // 2. Provjeri SharedPreferences za onboarding
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          _logger
              .d(">>> User is logged in => navigating to UserLocationsScreen");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const UserLocationsScreen(username: "Korisnik"),
            ),
          );
        } else {
          _logger.d(
              ">>> User not logged in => onboardingCompleted? $onboardingCompleted");
          if (onboardingCompleted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OnboardingScreen(
                  onFinish: () async {
                    _logger.d(
                        ">>> onFinish from Onboarding => set onboarding_completed=true and navigate to LoginScreen");
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_completed', true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    });
                  },
                  onSkip: () async {
                    _logger.d(
                        ">>> onSkip from Onboarding => set onboarding_completed=true and navigate to LoginScreen");
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_completed', true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    });
                  },
                ),
              ),
            );
          }
        }
      }
    };

    _controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
