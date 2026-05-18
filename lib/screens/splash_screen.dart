import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import '../services/subscription_service.dart';
import '../services/notification_service.dart';
import '../theme/design_system.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Hide status bar and navigation bar for a true full-screen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeAndNavigate();
  }

  @override
  void dispose() {
    // Restore system UI when leaving the splash screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initializeAndNavigate() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('DEBUG: Loading .env...');
      await dotenv.load(fileName: ".env");

      debugPrint('DEBUG: Initializing Supabase...');
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );

      debugPrint('DEBUG: Initializing AuthService...');
      await AuthService.init();

      debugPrint('DEBUG: Initializing AIService...');
      AIService().init();

      debugPrint('DEBUG: Initializing SubscriptionService...');
      await SubscriptionService().init();

      debugPrint('DEBUG: Initializing NotificationService...');
      final notificationService = NotificationService();
      await notificationService.init();
      
      debugPrint('DEBUG: Refreshing Notification Schedule...');
      await notificationService.refreshScheduledNotifications();
      
      debugPrint('DEBUG: All services initialized');
    } catch (e) {
      debugPrint('CRITICAL ERROR during initialization: $e');
    }

    // Ensure we show the splash for at least 3 seconds for branding
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 3000) {
      await Future.delayed(Duration(milliseconds: 3000 - elapsed));
    }

    if (!mounted) return;
    
    // Restore UI right before moving to the main app layout
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    // Exact background color from Image_1.png to ensure seamless blending
    const Color midnightNavy = Color(0xFF012E56);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/logo.jpeg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Subtle Bottom Fade
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.4),
                ],
                stops: const [0.7, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
