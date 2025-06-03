import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Definirajte ID-jeve vaših proizvoda
  static const String _kProductId5 = 'bulletin_5';
  static const String _kProductId15 = 'bulletin_15';

  Future<List<ProductDetails>> fetchProducts() async {
    Set<String> ids = {_kProductId5, _kProductId15};
    ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(ids);
    if (response.error != null) {
      // Handle the error.
      return [];
    }
    return response.productDetails;
  }

  void initialize(Function(PurchaseDetails) onPurchaseUpdated) {
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchases) {
      for (var purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased) {
          onPurchaseUpdated(purchase);
        } else if (purchase.status == PurchaseStatus.error) {
          // Handle the error
        }
      }
    }, onError: (error) {
      // Handle the error
    });
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
}
