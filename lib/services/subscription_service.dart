
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/constants.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    // await Purchases.setLogLevel(LogLevel.debug);

    // PurchasesConfiguration? configuration;
    
    // if (kIsWeb) {
    //   debugPrint('DEBUG: RevenueCat initialization skipped on Web');
    //   return;
    // }

    // if (defaultTargetPlatform == TargetPlatform.android) {
    //   configuration = PurchasesConfiguration(AppConstants.googleApiKey);
    // } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    //   configuration = PurchasesConfiguration(AppConstants.appleApiKey);
    // }

    // if (configuration != null) {
    //   await Purchases.configure(configuration);
    // }
    debugPrint('DEBUG: RevenueCat initialization bypassed for development');
  }

  /// Check if the user has an active 'pro_alerts' entitlement
  Future<bool> isProActive() async {
    return true; // MOCKED FOR BYPASS
  }

  /// Alias for isProActive
  Future<bool> isPremium() async => true;

  /// Alias for isProActive
  Future<bool> checkEntitlements() async => true;

  /// Mock for remaining routes in a billing cycle
  int get remainingRoutes => 99;

  /// Mock for total monthly route limit
  int get monthlyLimit => 100;

  /// Mock for any method fetching specific route counts
  Future<int> getRemainingRoutesCount() async => 99;

  /// Identify user in RevenueCat (should match Supabase Auth UID)
  Future<void> logIn(String userId) async {
    await Purchases.logIn(userId);
  }

  /// Log out from RevenueCat
  Future<void> logOut() async {
    await Purchases.logOut();
  }
}
