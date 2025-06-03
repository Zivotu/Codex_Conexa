import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/user_service.dart' as user_service;

class SettingsPaymentServiceScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const SettingsPaymentServiceScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  SettingsPaymentServiceScreenState createState() =>
      SettingsPaymentServiceScreenState();
}

class SettingsPaymentServiceScreenState
    extends State<SettingsPaymentServiceScreen> {
  int _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  final user_service.UserService userService = user_service.UserService();

  final Logger logger = Logger();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _initializeInAppPurchase();
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await userService.getUserDocument(user);

      if (data != null && mounted) {
        setState(() {
          _balance = data['balance'] ?? 0;
          _transactions =
              List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        });
      }
    }
  }

  Future<void> _initializeInAppPurchase() async {
    final available = await _inAppPurchase.isAvailable();
    setState(() {
      _isAvailable = available;
    });

    if (_isAvailable) {
      const Set<String> productIds = {'pay_25_usd'};
      final response = await _inAppPurchase.queryProductDetails(productIds);
      if (response.error == null) {
        setState(() {
          _products = response.productDetails;
        });
      } else {
        logger.e('Greška pri dohvaćanju proizvoda: ${response.error}');
      }
    }
  }

  Future<void> _buyProduct(String productId) async {
    final product = _products.firstWhere(
      (prod) => prod.id == productId,
      orElse: () => throw Exception('Proizvod nije pronađen.'),
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

    _inAppPurchase.purchaseStream.listen((List<PurchaseDetails> purchases) {
      for (var purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased) {
          _updateBalance(25); // Dodajte 25$ za kupljeni proizvod
          _inAppPurchase.completePurchase(purchase);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plaćanje uspješno!')),
          );
        } else if (purchase.status == PurchaseStatus.error) {
          _showErrorSnackBar('Greška pri kupnji: ${purchase.error}');
        }
      }
    });
  }

  Future<void> _updateBalance(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await userService.updateUserBalance(user, amount);
        _addTransaction(amount, 'add');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dodano $amount\$')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Greška pri ažuriranju stanja: $e');
        }
      }
    }
  }

  void _addTransaction(int amount, String type) {
    setState(() {
      _balance += amount;
      _transactions.add({
        'amount': amount,
        'timestamp': Timestamp.now(),
        'type': type,
      });
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis Plaćanja'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trenutno stanje: \$$_balance',
                style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isAvailable && _products.isNotEmpty
                  ? () => _buyProduct('pay_25_usd')
                  : null,
              child: const Text('Plati 25\$'),
            ),
            const SizedBox(height: 20),
            const Text('Povijest transakcija:', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  final date = transaction['timestamp'] != null
                      ? (transaction['timestamp'] as Timestamp).toDate()
                      : DateTime.now();
                  return ListTile(
                    title: Text(
                      '${transaction['type'] == 'add' ? 'Dodano' : 'Resetirano'}: ${transaction['amount']}\$',
                    ),
                    subtitle: Text(
                      'Vrijeme: ${date.toLocal().toString()}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
