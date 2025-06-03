// lib/screens/payment_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../services/subscription_service.dart';
import '../services/localization_service.dart';
import 'slot_management_screen.dart';

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
  DateTime? _activeSubscriptionEndDate;
  List<Map<String, dynamic>> _purchaseHistory = [];
  String? _errorMessage;

  final Map<String, String> planDisplayNames = {
    "1-location": "1 LOKACIJA",
    "2-locations": "2 LOKACIJE",
    "3-locations": "3 LOKACIJE",
  };

  final Map<String, int> planLevels = {
    "1-location": 1,
    "2-locations": 2,
    "3-locations": 3,
  };

  String _extractPlanId(String productId) => productId.split(":").last;

  @override
  void initState() {
    super.initState();
    Purchases.addCustomerInfoUpdateListener(_purchaserInfoUpdated);
    _fetchSubscriptionData();
    _fetchPurchaseHistory();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_purchaserInfoUpdated);
    super.dispose();
  }

  void _purchaserInfoUpdated(CustomerInfo purchaserInfo) {
    setState(() {
      _customerInfo = purchaserInfo;
      _activeProductId = purchaserInfo.activeSubscriptions.isNotEmpty
          ? purchaserInfo.activeSubscriptions.first
          : null;
    });
    _updateSubscriptionEndDate();
  }

  Future<void> _fetchSubscriptionData() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      if (_customerInfo != null &&
          _customerInfo!.activeSubscriptions.isNotEmpty) {
        _activeProductId = _customerInfo!.activeSubscriptions.first;
      } else {
        _activeProductId = null;
      }
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        _availablePackages = offerings.current!.availablePackages;
      } else {
        _availablePackages = [];
      }
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);
      await subscriptionService.loadCurrentSubscription();
    } catch (e) {
      debugPrint(
          "${localizationService.translate('errorFetchingSubscriptionData')}: $e");
      _availablePackages = [];
    }
    await _updateSubscriptionEndDate();
    setState(() => _isLoading = false);
  }

  Future<void> _updateSubscriptionEndDate() async {
    final endDate = await _getSubscriptionEndDate();
    setState(() => _activeSubscriptionEndDate = endDate);
  }

  Future<DateTime?> _getSubscriptionEndDate() async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.active.isNotEmpty) {
        final entitlement = customerInfo.entitlements.active.values.first;
        if (entitlement.expirationDate != null) {
          return DateTime.parse(entitlement.expirationDate!).toLocal();
        }
      }
    } catch (e) {
      debugPrint("${localizationService.translate('errorGettingEndDate')}: $e");
    }
    return null;
  }

  String _getButtonLabel(String productId) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    if (_activeProductId == null) {
      return localizationService.translate('choose');
    }
    if (productId == _activeProductId) {
      return localizationService.translate('active');
    }
    final activePlan = _extractPlanId(_activeProductId!);
    final newPlan = _extractPlanId(productId);
    final currentLevel = planLevels[activePlan] ?? 0;
    final newLevel = planLevels[newPlan] ?? 0;
    return newLevel > currentLevel
        ? localizationService.translate('upgrade')
        : (newLevel < currentLevel
            ? localizationService.translate('downgrade')
            : localizationService.translate('change'));
  }

  bool _isUpgrade(String newProductId) {
    if (_activeProductId == null) return false;
    final activePlan = _extractPlanId(_activeProductId!);
    final newPlan = _extractPlanId(newProductId);
    return (planLevels[newPlan] ?? 0) > (planLevels[activePlan] ?? 0);
  }

  bool _isDowngrade(String newProductId) {
    if (_activeProductId == null) return false;
    final activePlan = _extractPlanId(_activeProductId!);
    final newPlan = _extractPlanId(newProductId);
    return (planLevels[newPlan] ?? 0) < (planLevels[activePlan] ?? 0);
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
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final productId = package.storeProduct.identifier;
      final customerInfo = await Purchases.purchasePackage(package);
      if (customerInfo.activeSubscriptions.contains(productId)) {
        final endDate = await _getSubscriptionEndDate();
        if (endDate != null && mounted) {
          final subscriptionService =
              Provider.of<SubscriptionService>(context, listen: false);
          await subscriptionService.loadCurrentSubscription();
          setState(() {
            _activeProductId = productId;
            _activeSubscriptionEndDate = endDate;
          });
          _fetchPurchaseHistory();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  localizationService.translate('subscriptionPurchased'))));
        }
      }
    } catch (e, stackTrace) {
      debugPrint("Error purchasing package: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizationService.translate('purchaseError'))));
    }
  }

  Future<void> _upgradeSubscription(Package package) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final newProductId = package.storeProduct.identifier;
      final effectiveOldSku = _activeProductId!.split(":")[0];
      final upgradeInfo = UpgradeInfo(effectiveOldSku,
          prorationMode: ProrationMode.immediateWithoutProration);
      final customerInfo =
          await Purchases.purchasePackage(package, upgradeInfo: upgradeInfo);
      if (customerInfo.activeSubscriptions.contains(newProductId)) {
        final endDate = await _getSubscriptionEndDate();
        if (endDate != null && mounted) {
          final subscriptionService =
              Provider.of<SubscriptionService>(context, listen: false);
          await subscriptionService.loadCurrentSubscription();
          setState(() {
            _activeProductId = newProductId;
            _activeSubscriptionEndDate = endDate;
          });
          _fetchPurchaseHistory();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(localizationService.translate('subscriptionUpgraded'))));
        }
      }
    } catch (e, stackTrace) {
      debugPrint("Error upgrading subscription: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizationService.translate('upgradeError'))));
    }
  }

  Future<void> _scheduleDowngrade(String newProductId) async {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('DowngradeRequests')
          .doc('pending')
          .set({
        'newProductId': newProductId,
        'requestedAt': DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(localizationService.translate('downgradeScheduled'))),
      );
    } catch (e, stackTrace) {
      debugPrint("Error scheduling downgrade: $e\n$stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localizationService.translate('downgradeError'))));
    }
  }

  Future<void> _fetchPurchaseHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('SubscriptionHistory')
          .orderBy('purchaseDate', descending: true)
          .get();
      setState(() {
        _purchaseHistory = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      debugPrint("Error fetching purchase history: $e");
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      setState(() {
        _errorMessage = localizationService.translate('purchaseHistoryError');
      });
    }
  }

  Future<void> _openSubscriptionManagement() async {
    const urlAndroid = "https://play.google.com/store/account/subscriptions";
    const urlIOS = "https://apps.apple.com/account/subscriptions";
    final url =
        Theme.of(context).platform == TargetPlatform.iOS ? urlIOS : urlAndroid;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(localizationService.translate('manageSubscriptionError'))),
      );
    }
  }

  String formatPrice(num price) {
    final formatter =
        NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 2);
    return formatter.format(price);
  }

  String formatPurchaseDate(DateTime date) {
    return DateFormat("dd.MM.yyyy. (HH:mm)").format(date);
  }

  Widget _buildActiveSubscriptionDetails() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    if (_activeProductId == null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.grey[100],
        elevation: 3,
        child: ListTile(
          leading: const Icon(Icons.subscriptions,
              color: Colors.blueAccent, size: 32),
          title: Text(
            localizationService.translate('noActiveSubscription'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.settings, color: Colors.blueAccent),
            onPressed: _openSubscriptionManagement,
            tooltip: localizationService.translate('manageSubscription'),
          ),
        ),
      );
    } else {
      final plan = planDisplayNames[_extractPlanId(_activeProductId!)] ??
          _extractPlanId(_activeProductId!);
      final formattedEndDate = _activeSubscriptionEndDate != null
          ? "${localizationService.translate('expires')}: ${DateFormat("dd.MM.yyyy. (HH:mm)").format(_activeSubscriptionEndDate!)}"
          : "";
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.grey[100],
        elevation: 3,
        child: ListTile(
          leading: const Icon(Icons.subscriptions,
              color: Colors.blueAccent, size: 32),
          title: Text(plan,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          subtitle:
              Text(formattedEndDate, style: const TextStyle(fontSize: 16)),
          trailing: IconButton(
            icon: const Icon(Icons.settings, color: Colors.blueAccent),
            onPressed: _openSubscriptionManagement,
            tooltip: localizationService.translate('manageSubscription'),
          ),
        ),
      );
    }
  }

  Widget _buildPlanCard(Package pkg) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    final productId = pkg.storeProduct.identifier;
    final plan = planDisplayNames[_extractPlanId(productId)] ??
        _extractPlanId(productId);
    final buttonLabel = _getButtonLabel(productId);
    final isActivePlan = productId == _activeProductId;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          plan,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isActivePlan ? Colors.blueAccent : Colors.orange,
          ),
        ),
        subtitle: Text(
          "${localizationService.translate('price')}: ${pkg.storeProduct.priceString ?? localizationService.translate('unknownPrice')} / ${localizationService.translate('month')}",
          style: const TextStyle(fontSize: 16),
        ),
        trailing: ElevatedButton(
          onPressed: buttonLabel == localizationService.translate('active')
              ? null
              : () async {
                  await _handleSubscriptionPress(pkg);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(buttonLabel, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildAvailablePlans() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizationService.translate('availablePackages'),
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availablePackages.length,
          itemBuilder: (context, index) {
            return _buildPlanCard(_availablePackages[index]);
          },
        ),
      ],
    );
  }

  Widget _buildPurchaseHistory() {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizationService.translate('purchaseHistory'),
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        _purchaseHistory.isEmpty
            ? Text(
                localizationService.translate('noPurchaseHistory'),
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purchaseHistory.length,
                itemBuilder: (context, index) {
                  final history = _purchaseHistory[index];
                  final String plan = history['productId'] != null
                      ? (planDisplayNames[
                              _extractPlanId(history['productId'])] ??
                          _extractPlanId(history['productId']))
                      : localizationService.translate('unknown');
                  final rawEventData =
                      history['rawEventData'] as Map<String, dynamic>?;
                  final dynamic priceData =
                      rawEventData != null ? rawEventData['price'] : null;
                  final String price = (priceData is num)
                      ? formatPrice(priceData)
                      : localizationService.translate('unknownPrice');
                  final purchaseDate =
                      (history['purchaseDate'] as Timestamp).toDate();
                  final formattedPurchaseDate =
                      formatPurchaseDate(purchaseDate);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        plan,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                              "${localizationService.translate('price')}: $price",
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                              "${localizationService.translate('purchased')}: $formattedPurchaseDate",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizationService =
        Provider.of<LocalizationService>(context, listen: true);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(localizationService.translate('subscriptionManagement'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: () async {
                await _fetchSubscriptionData();
                await _fetchPurchaseHistory();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    _buildActiveSubscriptionDetails(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const SlotManagementScreen()),
                        );
                      },
                      icon: const Icon(Icons.location_on),
                      label: Text(
                          localizationService.translate('manageLocations')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAvailablePlans(),
                    const SizedBox(height: 24),
                    _buildPurchaseHistory(),
                  ],
                ),
              ),
            ),
    );
  }
}

String formatPrice(num price) {
  final formatter =
      NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 2);
  return formatter.format(price);
}

String formatPurchaseDate(DateTime date) {
  return DateFormat("dd.MM.yyyy. (HH:mm)").format(date);
}
