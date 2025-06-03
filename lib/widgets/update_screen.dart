// lib/widgets/update_screen.dart

import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Za učitavanje JSON datoteke
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for permissions
import 'package:device_info_plus/device_info_plus.dart'; // Added for device info

class UpdateScreen extends StatefulWidget {
  final String updateUrl;

  const UpdateScreen({required this.updateUrl, super.key});

  @override
  UpdateScreenState createState() => UpdateScreenState();
}

class UpdateScreenState extends State<UpdateScreen> {
  double _progress = 0.0;
  String _updateText = ''; // Varijabla za tekst ažuriranja
  String _randomImage = '';
  late Dio _dio;
  final Logger _logger = Logger();
  bool _downloadComplete =
      false; // Dodana varijabla za praćenje završetka preuzimanja
  String _eta = ''; // Varijabla za procijenjeno vrijeme završetka
  bool _isDownloading =
      false; // Varijabla za onemogućavanje gumba za preuzimanje
  bool _isInstalling =
      false; // Varijabla za onemogućavanje gumba za instalaciju
  int?
      _expectedApkSize; // Očekivana veličina APK-a (može se postaviti iz JSON-a)

  @override
  void initState() {
    super.initState();
    _loadUpdateInfo(); // Učitaj informacije o ažuriranju odmah pri inicijalizaciji
    final random = Random();
    int imageIndex = random.nextInt(8) + 1; // Broj između 1 i 8
    _randomImage = 'assets/images/update_$imageIndex.jpg';

    _dio = Dio();
  }

  Future<void> _loadUpdateInfo() async {
    try {
      final String response =
          await rootBundle.loadString('assets/update_info.json');
      final data = json.decode(response);
      setState(() {
        _updateText = data['updateText'] ?? 'Ažuriranje aplikacije...';
        _expectedApkSize =
            data['expectedApkSize']; // Dodano za validaciju veličine
      });
      _logger.d("Update info loaded: $_updateText");
    } catch (e) {
      _logger.e("Greška pri učitavanju update_info.json: $e");
      setState(() {
        _updateText = 'Ažuriranje aplikacije...';
      });
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return; // Spriječi dvostruko klikanje
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _eta = '';
    });

    // Provjera dopuštenja za pohranu
    if (Platform.isAndroid) {
      var deviceInfoPlugin = DeviceInfoPlugin();
      var info = await deviceInfoPlugin.androidInfo;
      if (info.version.sdkInt >= 30) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            if (status.isPermanentlyDenied) {
              _logger.e('Dopuštenje za pohranu je trajno odbijeno.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Dopuštenje za pohranu je trajno odbijeno. Molimo omogućite ga u postavkama aplikacije.'),
                ),
              );
              await openAppSettings();
            } else {
              _logger.e('Dopuštenje za pohranu nije odobreno.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Dopuštenje za pohranu je potrebno za preuzimanje.'),
                ),
              );
            }
            setState(() {
              _isDownloading = false;
            });
            return;
          }
        }
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (status.isPermanentlyDenied) {
              _logger.e('Dopuštenje za pohranu je trajno odbijeno.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Dopuštenje za pohranu je trajno odbijeno. Molimo omogućite ga u postavkama aplikacije.'),
                ),
              );
              await openAppSettings();
            } else {
              _logger.e('Dopuštenje za pohranu nije odobreno.');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Dopuštenje za pohranu je potrebno za preuzimanje.'),
                ),
              );
            }
            setState(() {
              _isDownloading = false;
            });
            return;
          }
        }
      }
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/app-release.apk';
    final file = File(filePath);
    final startTime = DateTime.now();

    try {
      await _dio.download(
        widget.updateUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            setState(() {
              _progress = progress;
            });

            // Izračunaj brzinu preuzimanja (bytes/s)
            final elapsed = DateTime.now().difference(startTime).inSeconds;
            if (elapsed > 0) {
              double speed = received / elapsed;
              // Procijenjeno vrijeme završetka (sekunde)
              double etaSeconds = (total - received) / speed;
              Duration etaDuration = Duration(seconds: etaSeconds.toInt());
              setState(() {
                _eta =
                    '${etaDuration.inMinutes}m ${etaDuration.inSeconds % 60}s';
              });
            }
          }
        },
      );

      _logger.d("APK preuzet.");

      // Provjera postojanja datoteke nakon preuzimanja
      if (await file.exists()) {
        _logger.d(
            'APK datoteka je uspješno preuzeta i postoji na putanji: $filePath');
      } else {
        _logger.e('APK datoteka nije pronađena nakon preuzimanja.');
        throw Exception("APK datoteka nije pronađena nakon preuzimanja.");
      }

      // Validacija APK-a
      bool isValid = await _validateApk(file);
      if (isValid) {
        setState(() {
          _downloadComplete = true;
        });
      } else {
        throw Exception("APK validacija nije uspjela.");
      }
    } catch (e) {
      _logger.e('Error downloading APK: $e');
      // Prikazivanje poruke o grešci korisniku
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri preuzimanju ažuriranja: $e'),
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<bool> _validateApk(File file) async {
    try {
      // Provjera veličine APK-a
      if (_expectedApkSize != null) {
        final fileSize = await file.length();
        if (fileSize != _expectedApkSize) {
          _logger.e(
              "APK validacija neuspjela: očekivana veličina $_expectedApkSize, stvarna veličina $fileSize");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('APK datoteka nije valjana. Pokušajte ponovo.'),
            ),
          );
          return false;
        }
      }

      _logger.d("APK validacija uspješna.");
      return true;
    } catch (e) {
      _logger.e("Greška pri validaciji APK-a: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri validaciji APK-a: $e'),
        ),
      );
      return false;
    }
  }

  Future<void> _installApk(BuildContext context) async {
    if (_isInstalling) return; // Spriječi dvostruko klikanje
    setState(() {
      _isInstalling = true;
    });

    try {
      if (Platform.isAndroid) {
        bool hasPermission = await _isInstallPermissionGranted();
        if (!hasPermission) {
          bool settingsOpened = await _showInstallPermissionDialog(context);
          if (!settingsOpened) {
            setState(() {
              _isInstalling = false;
            });
            return;
          }
        }

        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/app-release.apk';
        final file = File(filePath);

        // Provjera postojanja datoteke
        if (!await file.exists()) {
          throw Exception("APK datoteka nije pronađena na putanji: $filePath");
        } else {
          _logger.d('APK datoteka je pronađena na putanji: $filePath');
        }

        // Ponovna validacija prije instalacije
        bool isValid = await _validateApk(file);
        if (!isValid) {
          setState(() {
            _isInstalling = false;
          });
          return;
        }

        // Otvaranje datoteke za instalaciju
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          throw Exception("Greška pri otvaranju APK datoteke.");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Instalacija nije podržana na ovoj platformi.")),
        );
      }
    } catch (e) {
      _logger.e("Error during APK installation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri instalaciji: $e')),
      );
    } finally {
      setState(() {
        _isInstalling = false;
      });
    }
  }

  Future<bool> _isInstallPermissionGranted() async {
    if (Platform.isAndroid) {
      // Provjera verzije Androida
      var deviceInfo = DeviceInfoPlugin();
      var info = await deviceInfo.androidInfo;
      if (info.version.sdkInt >= 26) {
        // Android 8.0 (API 26)+
        if (await Permission.requestInstallPackages.isGranted) {
          return true;
        } else {
          var status = await Permission.requestInstallPackages.status;
          if (!status.isGranted) {
            status = await Permission.requestInstallPackages.request();
          }
          return status.isGranted;
        }
      }
    }
    return false;
  }

  Future<bool> _showInstallPermissionDialog(BuildContext context) async {
    bool settingsOpened = false;
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dozvola za instalaciju aplikacija'),
          content: const Text(
              'Molimo omogućite instalaciju aplikacija izvan Play trgovine u postavkama.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Otkaži'),
            ),
            TextButton(
              onPressed: () async {
                bool opened = await openAppSettings();
                if (opened) {
                  settingsOpened = true;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Otvori Postavke'),
            ),
          ],
        ),
      );
    } catch (e) {
      _logger.e("Error opening app settings: $e");
    }
    return settingsOpened;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Plava pozadina
          Container(
            color: Colors.blue,
          ),
          // Prikaz nasumično odabrane slike s 'contain' fitom za cijeli ekran
          Center(
            child: Image.asset(
              _randomImage,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Veći krug s postotkom na sredini
              CustomCircularProgressBar(progress: _progress),
              const SizedBox(height: 20),
              // Prikaz procijenjenog vremena završetka
              if (_eta.isNotEmpty)
                Text(
                  'Procijenjeno vrijeme završetka: $_eta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 50),
              // Gumb za akciju
              if (!_downloadComplete)
                ElevatedButton(
                  onPressed: _isDownloading
                      ? null
                      : () async {
                          await _startDownload();
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 40.0),
                    backgroundColor: _isDownloading
                        ? Colors.grey
                        : Colors.green, // Zelena boja gumba
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold, // Masna slova
                      color: Colors.white, // Bijela boja teksta
                    ),
                  ),
                  child: Text(
                    _isDownloading ? 'PREUZIMANJE...' : 'PREUZMI',
                    style: const TextStyle(
                      color: Colors.white, // Tekst u bijeloj boji
                    ),
                  ),
                ),
              if (_downloadComplete)
                ElevatedButton(
                  onPressed: _isInstalling
                      ? null
                      : () async {
                          await _installApk(context);
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 40.0),
                    backgroundColor: _isInstalling
                        ? Colors.grey
                        : Colors.green, // Zelena boja gumba
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold, // Masna slova
                      color: Colors.white, // Bijela boja teksta
                    ),
                  ),
                  child: Text(
                    _isInstalling ? 'INSTALIRANJE...' : 'INSTALIRAJ',
                    style: const TextStyle(
                      color: Colors.white, // Tekst u bijeloj boji
                    ),
                  ),
                ),
            ],
          ),
          // Prikaz informacija o ažuriranju
          Positioned(
            bottom: 150,
            left: 24,
            right: 24,
            child: Text(
              _updateText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomCircularProgressBar extends StatelessWidget {
  final double progress;

  const CustomCircularProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(200, 200), // Duplo veća kružnica
      painter: ProgressBarPainter(progress),
    );
  }
}

class ProgressBarPainter extends CustomPainter {
  final double progress;
  ProgressBarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 16.0
      ..style = PaintingStyle.stroke;

    Paint progressPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 16.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2, paint);

    double angle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2),
      -3.14159 / 2,
      angle,
      false,
      progressPaint,
    );

    // Prikaz broja unutar kružnice
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).toInt()}%',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant ProgressBarPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
