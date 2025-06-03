import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentDashboardScreen extends StatefulWidget {
  const PaymentDashboardScreen({super.key});

  @override
  _PaymentDashboardScreenState createState() => _PaymentDashboardScreenState();
}

class _PaymentDashboardScreenState extends State<PaymentDashboardScreen> {
  CustomerInfo? _customerInfo;
  bool _isLoading = true;
  List<Package> _availablePackages = [];
  String? _activeProductId;

  final Map<String, int> planLevels = {
    "single-location": 1,
    "double-location": 2,
    "triple-location": 3,
  };

  // Funkcija koja izvlači plan id iz punog identifier-a (dio iza ':')
  String _extractPlanId(String productId) {
    return productId; // Nema više potrebe za splitanjem jer su nazivi već ispravni.
  }

  @override
  void initState() {
    super.initState();
    Purchases.addCustomerInfoUpdateListener(_purchaserInfoUpdated);
    _fetchSubscriptionData();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_purchaserInfoUpdated);
    super.dispose();
  }

  void _purchaserInfoUpdated(CustomerInfo purchaserInfo) {
    debugPrint("CustomerInfo updated: ${purchaserInfo.activeSubscriptions}");
    setState(() {
      _customerInfo = purchaserInfo;
      if (purchaserInfo.activeSubscriptions.isNotEmpty) {
        _activeProductId = purchaserInfo.activeSubscriptions.first;
      } else {
        _activeProductId = null;
      }
    });
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      debugPrint(
          "Fetched customer info, activeSubscriptions: ${_customerInfo?.activeSubscriptions}");
      if (_customerInfo!.activeSubscriptions.isNotEmpty) {
        _activeProductId = _customerInfo!.activeSubscriptions.first;
      }
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        _availablePackages = offerings.current!.availablePackages;
        debugPrint(
            "Available packages: ${_availablePackages.map((p) => p.storeProduct.identifier).toList()}");
      }
    } catch (e) {
      debugPrint("Error fetching subscription data: $e");
    }
    setState(() {
      _isLoading = false;
    });
  }

  String _getButtonLabel(String productId) {
    final activePlan =
        _activeProductId != null ? _extractPlanId(_activeProductId!) : null;
    final newPlan = _extractPlanId(productId);
    if (activePlan == null) return "Select";
    if (newPlan == activePlan) return "Active";
    final currentLevel = planLevels[activePlan] ?? 0;
    final newLevel = planLevels[newPlan] ?? 0;
    return newLevel > currentLevel
        ? "Upgrade"
        : (newLevel < currentLevel ? "Downgrade" : "Switch");
  }

  bool _isUpgrade(String newProductId) {
    if (_activeProductId == null) return false;
    final activePlan = _extractPlanId(_activeProductId!);
    final newPlan = _extractPlanId(newProductId);
    final currentLevel = planLevels[activePlan] ?? 0;
    final newLevel = planLevels[newPlan] ?? 0;
    return newLevel > currentLevel;
  }

  bool _isDowngrade(String newProductId) {
    if (_activeProductId == null) return false;
    final activePlan = _extractPlanId(_activeProductId!);
    final newPlan = _extractPlanId(newProductId);
    final currentLevel = planLevels[activePlan] ?? 0;
    final newLevel = planLevels[newPlan] ?? 0;
    return newLevel < currentLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Subscription",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(_activeProductId ?? "None"),
                      subtitle: const Text("Manage your subscription below."),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Available Plans",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _availablePackages.length,
                      itemBuilder: (context, index) {
                        final pkg = _availablePackages[index];
                        final productId = pkg.storeProduct.identifier;
                        final buttonLabel = _getButtonLabel(productId);
                        return Card(
                          child: ListTile(
                            title: Text(pkg.storeProduct.title),
                            subtitle:
                                Text("Price: ${pkg.storeProduct.priceString}"),
                            trailing: ElevatedButton(
                              onPressed: buttonLabel == "Active"
                                  ? null
                                  : () async {
                                      await _handleSubscriptionPress(pkg);
                                    },
                              child: Text(buttonLabel),
                            ),
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

  Future<void> _handleSubscriptionPress(Package package) async {
    final productId = package.storeProduct.identifier;
    if (_activeProductId == null) {
      await _purchasePackage(package);
      return;
    }
    if (_isUpgrade(productId)) {
      await _upgradeSubscription(package);
    } else if (_isDowngrade(productId)) {
      await _scheduleDowngrade(productId);
    } else {
      await _purchasePackage(package);
    }
  }

  Future<void> _purchasePackage(Package package) async {
    try {
      final productId = package.storeProduct.identifier;
      debugPrint("Purchasing package for productId: $productId");
      final customerInfo = await Purchases.purchasePackage(package);
      debugPrint(
          "Purchase complete. Active subscriptions: ${customerInfo.activeSubscriptions}");
      if (customerInfo.activeSubscriptions.contains(productId)) {
        final endDate = await _getSubscriptionEndDate();
        debugPrint("Subscription end date: $endDate");
        await _saveSubscriptionToFirestore(productId, endDate);
        setState(() {
          _activeProductId = productId;
        });
      } else {
        debugPrint("Product $productId not found in active subscriptions.");
      }
    } catch (e, stackTrace) {
      debugPrint("Error purchasing package: $e");
      debugPrint("$stackTrace");
    }
  }

  Future<void> _upgradeSubscription(Package package) async {
    try {
      final newProductId = package.storeProduct.identifier;
      debugPrint(
          "Upgrade: Current SKU: $_activeProductId, New SKU: $newProductId");

      if (_activeProductId == null) {
        debugPrint(
            "No active subscription found. Performing regular purchase.");
        await _purchasePackage(package);
        return;
      }

      final upgradeInfo = UpgradeInfo(
        _activeProductId!, // Ovo sada direktno koristi aktivni SKU
        prorationMode: ProrationMode.immediateAndChargeProratedPrice,
      );

      final customerInfo = await Purchases.purchasePackage(
        package,
        upgradeInfo: upgradeInfo,
      );

      debugPrint(
          "Upgrade: Purchase completed. Active subs: ${customerInfo.activeSubscriptions}");

      if (customerInfo.activeSubscriptions.contains(newProductId)) {
        final endDate = await _getSubscriptionEndDate();
        await _saveSubscriptionToFirestore(newProductId, endDate);
        setState(() {
          _activeProductId = newProductId;
        });
      } else {
        debugPrint("Upgrade: No matching subscription found after purchase.");
      }
    } catch (e, stackTrace) {
      debugPrint("Error upgrading subscription: $e");
      debugPrint("$stackTrace");
    }
  }

  Future<void> _scheduleDowngrade(String newProductId) async {
    try {
      debugPrint("Scheduling downgrade to: $newProductId");
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Schedule downgrade: No user logged in");
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('DowngradeRequests')
          .doc('pending')
          .set({
        'newProductId': newProductId,
        'requestedAt': DateTime.now().toIso8601String(),
      });
      debugPrint("Downgrade scheduled successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Your downgrade request has been scheduled to take effect at the end of your current billing period."),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("Error scheduling downgrade: $e");
      debugPrint("$stackTrace");
    }
  }

  Future<DateTime?> _getSubscriptionEndDate() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.active.isNotEmpty) {
        final entitlement = customerInfo.entitlements.active.values.first;
        if (entitlement.expirationDate != null) {
          return DateTime.parse(entitlement.expirationDate!);
        }
      }
    } catch (e) {
      debugPrint("Error getting subscription end date: $e");
    }
    return null;
  }

  Future<void> _saveSubscriptionToFirestore(
      String productId, DateTime? endDate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Subscriptions')
        .doc('current')
        .set({
      'productId': productId,
      'isActive': true,
      'startDate': Timestamp.fromDate(DateTime.now()),
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
    });
  }
}
