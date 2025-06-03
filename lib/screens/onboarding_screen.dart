import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart'; // Za pristup LocalizationService
import '../services/localization_service.dart';

/// OnboardingScreen prima callback-ove onFinish i onSkip koji se pozivaju
/// kad korisnik završi ili preskoči onboarding.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const OnboardingScreen({
    required this.onFinish,
    required this.onSkip,
    super.key,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _navigationTriggered = false;

  // Koristimo postojeće ključeve za naslove i opise:
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.rocket_launch,
      titleKey: 'Welcome_1_title',
      descriptionKey: 'Welcome_1_description',
      color: Colors.blueAccent,
    ),
    OnboardingPageData(
      icon: Icons.build,
      titleKey: 'Welcome_2_title',
      descriptionKey: 'Welcome_2_description',
      color: Colors.green,
    ),
    OnboardingPageData(
      icon: Icons.apartment,
      titleKey: 'Welcome_3_title',
      descriptionKey: 'Welcome_3_description',
      color: Colors.orange,
    ),
    OnboardingPageData(
      icon: Icons.list,
      titleKey: 'Welcome_4_title',
      descriptionKey: 'Welcome_4_description',
      color: Colors.purple,
    ),
    OnboardingPageData(
      icon: Icons.star,
      titleKey: 'Welcome_5_title',
      descriptionKey: 'Welcome_5_description',
      color: Colors.redAccent,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_navigationTriggered) return;
      _navigationTriggered = true;
      Logger().d(">>> Onboarding: FINISH clicked, calling widget.onFinish()");
      // Umjesto postFrameCallback, koristimo Future.microtask
      Future.microtask(() {
        if (mounted) {
          widget.onFinish();
        }
      });
    }
  }

  void _skip() {
    if (_navigationTriggered) return;
    _navigationTriggered = true;
    Logger().d(">>> Onboarding: SKIP clicked, calling widget.onSkip()");
    // Koristimo Future.microtask kako bismo odmah zakazali poziv callbacka
    Future.microtask(() {
      if (mounted) {
        widget.onSkip();
      }
    });
  }

  /// Metoda koja gradi opis (dohvaća prijevode iz LocalizationService)
  Widget _buildDescription(String description) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final descText = localizationService.translate(description) ?? description;
    final lines = descText.split('\n');

    List<Widget> widgets = [];
    for (var line in lines) {
      if (line.startsWith('• ')) {
        final content = line.substring(2).split(' – ');
        if (content.length >= 2) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${content[0]} – ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          TextSpan(
                            text: content[1],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      line.substring(2),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else if (line.startsWith('✅ ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                const Text('✅ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    line.substring(3),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              line,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final page = _pages[_currentPage];
    final currentTitle =
        localizationService.translate(page.titleKey) ?? page.titleKey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: page.color,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              localizationService.translate('skip') ?? 'Skip',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Container(
        color: page.color.withOpacity(0.1),
        child: PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (int index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            final currentPageData = _pages[index];
            final titleText =
                localizationService.translate(currentPageData.titleKey) ??
                    currentPageData.titleKey;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    currentPageData.icon,
                    size: 120,
                    color: currentPageData.color,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    titleText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: currentPageData.color,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildDescription(currentPageData.descriptionKey),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: page.color,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          child: Text(
            _currentPage == _pages.length - 1
                ? (localizationService.translate('finish') ?? 'Finish')
                : (localizationService.translate('next') ?? 'Next'),
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final IconData icon;
  final String titleKey; // npr. "Welcome_1_title"
  final String descriptionKey; // npr. "Welcome_1_description"
  final Color color;

  OnboardingPageData({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}
