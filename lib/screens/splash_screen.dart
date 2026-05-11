import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../theme/design_system.dart';

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
    _navigateToHome();
  }

  @override
  void dispose() {
    // Restore system UI when leaving the splash screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    // Restore UI right before moving to the main app layout
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Container
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Haul Alerts',
              style: AppDesignSystem.headlineLarge.copyWith(
                color: AppDesignSystem.onBackground,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'PRECISION ROUTING & SAFETY',
              style: AppDesignSystem.labelLarge.copyWith(
                color: AppDesignSystem.primary,
                letterSpacing: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
