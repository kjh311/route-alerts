import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get appleApiKey => dotenv.get('REVENUECAT_APPLE_KEY', fallback: '');
  static String get googleApiKey => dotenv.get('REVENUECAT_GOOGLE_KEY', fallback: '');
  static const String proEntitlementId = 'pro_alerts';

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  static String get googleWebClientId => dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
}
