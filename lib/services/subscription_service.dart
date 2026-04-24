import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/constants.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(AppConstants.googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(AppConstants.appleApiKey);
    } else {
      // Handle other platforms if necessary
      return;
    }

    await Purchases.configure(configuration);
  }

  /// Check if the user has an active 'pro_alerts' entitlement
  Future<bool> isProActive() async {
    try {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[AppConstants.proEntitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint('Error fetching customer info: $e');
      return false;
    }
  }

  /// Identify user in RevenueCat (should match Supabase Auth UID)
  Future<void> logIn(String userId) async {
    await Purchases.logIn(userId);
  }

  /// Log out from RevenueCat
  Future<void> logOut() async {
    await Purchases.logOut();
  }
}
