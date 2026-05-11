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
  
  try {
    print('DEBUG: Loading .env...');
    await dotenv.load(fileName: ".env");
    print('DEBUG: .env loaded');

    print('DEBUG: Initializing Supabase...');
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    print('DEBUG: Supabase initialized');

    print('DEBUG: Initializing AuthService...');
    await AuthService.init();
    print('DEBUG: AuthService initialized');

    print('DEBUG: Initializing AIService...');
    AIService().init();
    print('DEBUG: AIService initialized');

    print('DEBUG: Initializing SubscriptionService...');
    await SubscriptionService().init();
    print('DEBUG: SubscriptionService initialized');

    print('DEBUG: Initializing NotificationService...');
    await NotificationService().init();
    print('DEBUG: NotificationService initialized');

    print('DEBUG: Running App...');
    runApp(const HaulAlertsApp());
  } catch (e, stack) {
    print('CRITICAL ERROR during initialization: $e');
    print('Stack trace: $stack');
    // Fallback UI in case of total failure
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('App failed to start: $e'),
        ),
      ),
    ));
  }
}


class HaulAlertsApp extends StatelessWidget {
  const HaulAlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
