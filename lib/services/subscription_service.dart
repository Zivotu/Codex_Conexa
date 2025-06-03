// lib/services/subscription_service.dart
import 'dart:io'; // DODANO: Za provjeru platforme (iOS/Android)
import 'package:flutter/services.dart'; // DODANO: Za PlatformException

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class SubscriptionService with ChangeNotifier {
  final Logger _logger = Logger();

  List<Package> _availablePackages = [];
  Map<String, dynamic>? _currentSubscription;
  String? _errorMessage;
  int slotCount = 0; // Maximum allowed active locations

  List<Package> get availablePackages => _availablePackages;
  Map<String, dynamic>? get currentSubscription => _currentSubscription;
  String? get errorMessage => _errorMessage;

  SubscriptionService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      String apiKey;
      if (Platform.isIOS) {
        apiKey =
            "appl_CcCWQjYxGHHOkAOUTvsQUygIDFs"; // TVOJ NOVI APPLE API KLJUČ
        _logger.i("Koristim Apple API ključ za RevenueCat.");
      } else if (Platform.isAndroid) {
        apiKey =
            "goog_aIQgWOvJPtXYYkjnlXtcjFbZzwI"; // TVOJ POSTOJEĆI GOOGLE API KLJUČ
        _logger.i("Koristim Google API ključ za RevenueCat.");
      } else {
        _logger.e("Nepodržana platforma za RevenueCat kupovine.");
        _errorMessage = "Nepodržana platforma za pretplate.";
        notifyListeners();
        return;
      }

      final purchasesConfiguration = PurchasesConfiguration(apiKey);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        purchasesConfiguration.appUserID = user.uid;
        _logger.i("RevenueCat konfiguriran s appUserID: ${user.uid}");
      } else {
        _logger.w(
            "RevenueCat konfiguriran bez appUserID (korisnik nije prijavljen u trenutku konfiguracije).");
      }

      await Purchases.configure(purchasesConfiguration);
      _logger.i("RevenueCat SDK uspješno konfiguriran.");

      final offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        _availablePackages = offerings.current!.availablePackages;
        _logger.i(
          'Dostupni paketi: ${_availablePackages.map((p) => p.identifier).toList()}',
        );
      } else {
        _logger.w('Nema dostupnih paketa u RevenueCat ponudama (offerings).');
        // Ovo je jedna od grešaka koju si vidio/la u logu ("There are no products registered...").
        // Trebaš definirati "Offerings" i "Products" u RevenueCat dashboardu.
      }
    } catch (e) {
      _logger.e(
          'Greška prilikom inicijalizacije RevenueCat-a ili dohvaćanja ponuda: $e');
      if (e.toString().contains("INVALID_CREDENTIALS") ||
          e.toString().contains("API Key is not recognized")) {
        _errorMessage =
            "Problem s API ključem za pretplate. Provjerite konfiguraciju.";
      } else {
        _errorMessage = "Greška pri inicijalizaciji pretplata.";
      }
    }
    notifyListeners();
  }

  Future<void> loadCurrentSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.w("Korisnik nije prijavljen, ne mogu učitati pretplatu.");
      _currentSubscription = null;
      slotCount = 0;
      notifyListeners();
      return;
    }

    try {
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Subscriptions')
          .doc('current')
          .get();

      if (subscriptionDoc.exists && subscriptionDoc.data() != null) {
        _currentSubscription = subscriptionDoc.data();
        bool isActive = _currentSubscription?['isActive'] ?? false;
        Timestamp? endDateTs = _currentSubscription?['endDate']
            as Timestamp?; // Sigurnije castanje
        DateTime? endDate = endDateTs?.toDate();

        // Provjera ako je endDate null prije usporedbe
        if (!isActive || (endDate != null && DateTime.now().isAfter(endDate))) {
          slotCount = 0; // Pretplata nije aktivna ili je istekla
          if (endDate != null && DateTime.now().isAfter(endDate)) {
            _logger.i("Pretplata je istekla: $endDate");
          } else if (!isActive) {
            _logger.i("Pretplata nije aktivna.");
          }
        } else {
          slotCount = _currentSubscription?['slotCount'] ?? 0;
        }
        _logger.i(
          "Učitana trenutna pretplata: $_currentSubscription, slotCount: $slotCount",
        );
      } else {
        _currentSubscription = null;
        slotCount = 0;
        _logger.w("Nema trenutne pretplate za korisnika ${user.uid}");
      }
    } catch (e) {
      _logger.e("Greška pri učitavanju trenutne pretplate: $e");
      _errorMessage = "Greška pri učitavanju pretplate.";
      _currentSubscription = null; // Resetiraj u slučaju greške
      slotCount = 0;
    }
    notifyListeners();
  }

  DateTime? getCurrentSubscriptionEndDate() {
    if (_currentSubscription != null &&
        _currentSubscription!['endDate'] is Timestamp) {
      // Provjeri tip prije castanja
      Timestamp ts = _currentSubscription!['endDate'] as Timestamp;
      return ts.toDate();
    }
    return null;
  }

  Future<bool> hasActiveSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Prvo provjeri RevenueCat za najsvježije podatke o pretplati ako je moguće
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // Provjeri ima li aktivnih prava (entitlements)
      // Ovdje trebaš znati ID svog 'entitlement-a' iz RevenueCat-a, npr. 'premium_access'
      // if (customerInfo.entitlements.all["VAŠ_ENTITLEMENT_ID"] != null &&
      //      customerInfo.entitlements.all["VAŠ_ENTITLEMENT_ID"]!.isActive) {
      //    _logger.i("RevenueCat kaže da korisnik ima aktivnu pretplatu preko entitlementa.");
      //    // Ovdje možeš ažurirati i Firestore bazu ako je potrebno
      //    return true;
      // }
      // Ako nemaš entitlementse ili želiš dodatnu provjeru iz Firestore-a:
    } catch (e) {
      _logger.e("Greška pri dohvaćanju CustomerInfo iz RevenueCat-a: $e");
      // Nastavi na provjeru iz Firestore-a kao fallback
    }

    // Fallback na provjeru iz Firestore baze (kako si imao/la)
    try {
      final subDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Subscriptions')
          .doc('current')
          .get();

      if (!subDoc.exists || subDoc.data() == null) return false;

      final data = subDoc.data()!;
      final isActive = data['isActive'] as bool? ?? false;
      final endDateTs = data['endDate'] as Timestamp?;

      if (!isActive || endDateTs == null) return false;

      final endDate = endDateTs.toDate();
      return DateTime.now().isBefore(endDate);
    } catch (e) {
      _logger.e("Greška pri provjeri pretplate iz Firestore-a: $e");
      return false;
    }
  }

  Future<bool> canActivateNewLocation() async {
    await loadCurrentSubscription(); // Osvježi podatke o pretplati
    // Dodatna provjera aktivne pretplate za svaki slučaj
    bool isActiveSub = await hasActiveSubscription();
    if (!isActiveSub) {
      _logger.i(
          "Korisnik nema aktivnu pretplatu, ne može aktivirati novu lokaciju.");
      return false;
    }
    _logger.i(
        "Provjera slotova: $slotCount postojećih, korisnik ${slotCount > 0 ? 'može' : 'ne može'} aktivirati novu lokaciju.");
    return slotCount > 0;
  }

  // DODAJEMO: Metoda za kupovinu paketa
  Future<bool> purchasePackage(Package packageToPurchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "Morate biti prijavljeni da biste izvršili kupovinu.";
      _logger.w(_errorMessage!);
      notifyListeners();
      return false;
    }

    try {
      _logger.i(
          "Pokušaj kupovine paketa: ${packageToPurchase.identifier} za korisnika ${user.uid}");
      CustomerInfo customerInfo =
          await Purchases.purchasePackage(packageToPurchase);

      // Provjeri je li kupovina uspješna i je li entitlement aktivan
      // Zamijeni "VAŠ_ENTITLEMENT_ID" s ID-em entitlementa koji si definirao u RevenueCat-u
      // za ovaj paket (npr., 'premium', 'pro_slots', itd.)
      final String relevantEntitlementId =
          "TVOJ_ENTITLEMENT_ID_ZA_OVAJ_PAKET"; // <<=== VAŽNO: Prilagodi ovo!

      if (customerInfo.entitlements.all[relevantEntitlementId] != null &&
          customerInfo.entitlements.all[relevantEntitlementId]!.isActive) {
        _logger.i(
            "Kupovina uspješna! Entitlement '$relevantEntitlementId' je aktivan.");
        // Ovdje bi trebao ažurirati status pretplate u svojoj Firestore bazi
        // Na primjer, pozvati funkciju koja zapisuje detalje iz customerInfo.entitlements.all[relevantEntitlementId]
        // await _updateSubscriptionInFirestore(customerInfo.entitlements.all[relevantEntitlementId]!);
        await loadCurrentSubscription(); // Ponovno učitaj da se prikažu promjene
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _logger.w(
            "Kupovina možda nije prošla ili entitlement '$relevantEntitlementId' nije aktivan.");
        _errorMessage = "Kupovina nije uspjela ili pretplata nije aktivirana.";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logger.e("Greška tijekom kupovine paketa: $e");
      if (e is PlatformException) {
        if (e.code == "1") {
          // PurchasesErrorCode.purchaseCancelledError
          _errorMessage = "Kupovina je otkazana.";
        } else {
          _errorMessage = e.message ?? "Došlo je do greške prilikom kupovine.";
        }
      } else {
        _errorMessage = "Došlo je do nepoznate greške prilikom kupovine.";
      }
      notifyListeners();
      return false;
    }
  }

  // DODAJEMO: Primjer metode za ažuriranje Firestore-a nakon uspješne kupovine (prilagodi svojim potrebama)
  // Future<void> _updateSubscriptionInFirestore(EntitlementInfo entitlement) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   // Odredi broj slotova na temelju kupljenog paketa/entitlementa
  //   // Ovo je primjer, tvoja logika može biti drugačija
  //   int purchasedSlotCount = 0;
  //   if (entitlement.productIdentifier.contains("small_package")) { // Primjer ID-a proizvoda
  //     purchasedSlotCount = 5;
  //   } else if (entitlement.productIdentifier.contains("large_package")) {
  //     purchasedSlotCount = 20;
  //   }

  //   final subscriptionData = {
  //     'isActive': entitlement.isActive,
  //     'productId': entitlement.productIdentifier,
  //     'purchaseDate': entitlement.latestPurchaseDateMillis != null
  //         ? Timestamp.fromMillisecondsSinceEpoch(entitlement.latestPurchaseDateMillis!)
  //         : FieldValue.serverTimestamp(),
  //     'endDate': entitlement.expirationDateMillis != null
  //         ? Timestamp.fromMillisecondsSinceEpoch(entitlement.expirationDateMillis!)
  //         : null, // Ili neki daleki datum ako je doživotna pretplata
  //     'store': entitlement.store.name, // 'APP_STORE', 'PLAY_STORE', itd.
  //     'isSandbox': entitlement.isSandbox,
  //     'slotCount': purchasedSlotCount, // Postavi broj slotova
  //     'originalPurchaseDate': entitlement.originalPurchaseDateMillis != null
  //         ? Timestamp.fromMillisecondsSinceEpoch(entitlement.originalPurchaseDateMillis!)
  //         : null,
  //     'periodType': entitlement.periodType.name,
  //     'unsubscribeDetectedAt': entitlement.unsubscribeDetectedAtDateMillis != null
  //         ? Timestamp.fromMillisecondsSinceEpoch(entitlement.unsubscribeDetectedAtDateMillis!)
  //         : null,
  //     'billingIssueDetectedAt': entitlement.billingIssueDetectedAtDateMillis != null
  //         ? Timestamp.fromMillisecondsSinceEpoch(entitlement.billingIssueDetectedAtDateMillis!)
  //         : null,

  //   };

  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .collection('Subscriptions')
  //         .doc('current') // Ili koristi entitlement.identifier kao ID dokumenta ako želiš pratiti više entitlementa
  //         .set(subscriptionData, SetOptions(merge: true));
  //     _logger.i("Pretplata ažurirana u Firestore-u za entitlement: ${entitlement.identifier}");
  //   } catch (e) {
  //     _logger.e("Greška pri ažuriranju pretplate u Firestore-u: $e");
  //   }
  // }
}
