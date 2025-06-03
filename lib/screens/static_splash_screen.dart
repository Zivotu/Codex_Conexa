// lib/screens/static_splash_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ovdje importamo checkForUpdate iz main.dart (ako si je tamo ostavio)
import '../main.dart' as mainFile;
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'user_locations_screen.dart';

class StaticSplashScreen extends StatefulWidget {
  const StaticSplashScreen({super.key});

  @override
  State<StaticSplashScreen> createState() => _StaticSplashScreenState();
}

class _StaticSplashScreenState extends State<StaticSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Čekamo 3 sekunde
    await Future.delayed(const Duration(seconds: 3));

    // 1) checkForUpdate
    bool updateChosen = await mainFile.checkForUpdate(context);
    // Ako widget unmountan, nema smisla dalje
    if (!mounted) return;

    // Ako je user izabrao update, obično app prelazi u background ili user ide na store.
    // Ne radimo daljnju navigaciju.
    if (updateChosen) {
      return;
    }

    // 2) normalno dalje
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // Možda je user zatvorio app pa se widget unmountao
    if (!mounted) return;

    if (FirebaseAuth.instance.currentUser != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const UserLocationsScreen(username: "Korisnik"),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => onboardingCompleted
              ? const LoginScreen()
              : OnboardingScreen(
                  onFinish: () async {
                    await prefs.setBool('onboarding_completed', true);
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  onSkip: () async {
                    await prefs.setBool('onboarding_completed', true);
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bijeli ekran s centralno ispisanim "CONEXA.life"
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'CONEXA.life',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
