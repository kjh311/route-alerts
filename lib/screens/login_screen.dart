import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/design_system.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().authenticate();
      // Navigation is handled by AuthWrapper via onAuthStateChange
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.marginEdge),
        decoration: const BoxDecoration(
          color: AppDesignSystem.background,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo or App Name
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    size: 80,
                    color: AppDesignSystem.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'HAUL ALERTS',
                    style: AppDesignSystem.displayLarge.copyWith(
                      color: AppDesignSystem.primary,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Precision Safety for Professionals',
                    style: AppDesignSystem.bodyMedium.copyWith(
                      color: AppDesignSystem.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),

            // Login Button
            if (kIsWeb)
              AuthService().buildWebButton()
            else if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary))
            else
              ElevatedButton(
                onPressed: _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(AppDesignSystem.touchTargetMin),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'SIGN IN WITH GOOGLE',
                      style: AppDesignSystem.labelBold.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            Text(
              'By signing in, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: AppDesignSystem.labelBold.copyWith(
                color: AppDesignSystem.outline,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
