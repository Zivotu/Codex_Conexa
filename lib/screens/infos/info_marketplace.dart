import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoMarketplaceScreen extends StatelessWidget {
  const InfoMarketplaceScreen({super.key});

  Future<void> _disableFuturePopups(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_marketplace_boarding', false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("O Marketplace-u"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Image.asset(
                  'assets/images/marketplace_info.png',
                  height: 200,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Dobrodošli u Marketplace",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ovo je mjesto na kojem ćete otkriti sve glede akcija u trgovinama, kulturnim događanjima, humanitarnim akcijama, live svirkama i sličnim događanjima u blizini Vašeg doma. Pogledate li gore desno vidjet ćete i kategoriju LETCI gdje možete prolistati prospekte iz različitih trgovačkih lanaca što ćemo s vremenom nadopunjavati.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _disableFuturePopups(context),
                  child: const Text("Ne prikazuj više"),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Zatvori"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
