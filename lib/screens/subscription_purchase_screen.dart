// lib/screens/subscription_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import 'constants.dart' as constants; // Use alias to resolve ambiguity

class SubscriptionPurchaseScreen extends StatefulWidget {
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const SubscriptionPurchaseScreen({
    super.key,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _SubscriptionPurchaseScreenState createState() =>
      _SubscriptionPurchaseScreenState();
}

class _SubscriptionPurchaseScreenState
    extends State<SubscriptionPurchaseScreen> {
  bool _isPurchasing = false;
  CustomerInfo? _customerInfo;
  String? _currentSubscription;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionData();
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      if (_customerInfo != null &&
          _customerInfo!.activeSubscriptions.isNotEmpty) {
        setState(() {
          _currentSubscription = _customerInfo!.activeSubscriptions.first;
        });
      }
    } catch (e) {
      debugPrint("Error fetching subscription info: $e");
    }
  }

  Future<void> _purchaseSubscription(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      await _fetchSubscriptionData();
      // With the new model, the webhook updates the subscription document;
      // no need to call saveSubscriptionToFirestore here.
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error purchasing subscription: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Greška pri kupnji: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionService = Provider.of<SubscriptionService>(context);
    final packages = subscriptionService.availablePackages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odaberi pretplatnički paket'),
        backgroundColor: Colors.teal,
      ),
      body: packages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentSubscription != null)
                    Card(
                      color: Colors.teal.shade50,
                      child: ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(
                            "Trenutna pretplata: ${constants.extractPlanId(_currentSubscription!)}"),
                        subtitle: const Text(
                            "Možete nadograditi ili promijeniti pretplatu."),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text("Dostupne pretplate",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: packages.length,
                      itemBuilder: (context, index) {
                        Package package = packages[index];
                        final storeProduct = package.storeProduct;
                        bool isCurrent = _currentSubscription != null &&
                            constants.extractPlanId(storeProduct.identifier) ==
                                constants.extractPlanId(_currentSubscription!);
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.subscriptions,
                                color: Colors.teal),
                            title: Text(storeProduct.title),
                            subtitle:
                                Text('Cijena: ${storeProduct.priceString}'),
                            trailing: isCurrent
                                ? const Text("Aktivno",
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold))
                                : ElevatedButton(
                                    onPressed: () async {
                                      setState(() => _isPurchasing = true);
                                      await _purchaseSubscription(package);
                                      setState(() => _isPurchasing = false);
                                    },
                                    child: const Text("Odaberi"),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton:
          _isPurchasing ? const CircularProgressIndicator() : null,
    );
  }
}
