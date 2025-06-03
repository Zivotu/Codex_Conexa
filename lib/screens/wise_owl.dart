import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';

class WiseOwlScreen extends StatefulWidget {
  const WiseOwlScreen({super.key});

  @override
  State<WiseOwlScreen> createState() => _WiseOwlScreenState();
}

class _WiseOwlScreenState extends State<WiseOwlScreen> {
  String? dailySaying;

  @override
  void initState() {
    super.initState();
    _fetchSaying();
  }

  Future<void> _fetchSaying() async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(
          'gs://conexaproject-9660d.appspot.com/sayings/sayings.json');
      final String url = await ref.getDownloadURL();

      // Dohvaćanje odgovora i osiguravanje ispravnog dekodiranja
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final utf8Body =
            utf8.decode(response.bodyBytes); // Osiguravanje UTF-8 dekodiranja
        final List<dynamic> sayings =
            jsonDecode(utf8Body)['sayings'] as List<dynamic>;
        setState(() {
          // Prikazujemo poslovicu na temelju dana u godini
          final int dayOfYear =
              DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
          dailySaying = sayings[dayOfYear % sayings.length];
        });
      } else {
        setState(() {
          dailySaying = 'Nismo uspjeli dohvatiti poslovicu. Pokušajte kasnije.';
        });
      }
    } catch (e) {
      setState(() {
        dailySaying = 'Došlo je do pogreške. Pokušajte kasnije.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pozadinska slika
          Image.asset(
            'assets/images/owl_vertical_bg_1.jpg',
            fit: BoxFit.cover,
          ),
          // Tekstualni sadržaj
          Padding(
            padding: const EdgeInsets.all(50.0),
            child: Center(
              child: dailySaying == null
                  ? const CircularProgressIndicator()
                  : Text(
                      dailySaying!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily:
                            'Lato', // Zamijenite s fontom koji podržava HR znakove
                        color: Colors.black,
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            offset: Offset(1.5, 1.5),
                            blurRadius: 2.0,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
