import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get appleApiKey => dotenv.get('REVENUECAT_APPLE_KEY', fallback: '');
  static String get googleApiKey => dotenv.get('REVENUECAT_GOOGLE_KEY', fallback: '');
  static const String proEntitlementId = 'pro_alerts';

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  static String get googleWebClientId => dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
  static String get googleMapsApiKey => dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');
  static String get openWeatherApiKey {
    final key = dotenv.get('OPENWEATHER_API_KEY', fallback: '');
    if (key.isEmpty || key == 'your_openweather_key_here') {
      debugPrint('Warning: OpenWeather API Key is missing from .env file.');
    }
    return key;
  }
}
