    import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'screens/auth_wrapper.dart';
import 'screens/splash_screen.dart';
import 'theme/design_system.dart';
import 'services/subscription_service.dart';
import 'services/auth_service.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaulAlertsApp());
}


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HaulAlertsApp extends StatelessWidget {
  const HaulAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the key
      debugShowCheckedModeBanner: false,
      title: 'Haul Alerts',
      theme: AppDesignSystem.themeData,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const AuthWrapper(),
      },
    );
  }
}
