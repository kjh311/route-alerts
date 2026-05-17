import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_system.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _userEmail = _supabase.auth.currentUser?.email;
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppDesignSystem.surfaceContainer,
        title: const Text('DELETE ACCOUNT?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This will delete all your routes and data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = _supabase.auth.currentUser!.id;

        // Delete all routes for this user
        await _supabase.from('routes').delete().eq('user_id', userId);

        // Delete profile
        await _supabase.from('profiles').delete().eq('id', userId);

        // Sign out
        await _supabase.auth.signOut();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.marginEdge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Account',
                style: AppDesignSystem.headlineMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppDesignSystem.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userEmail ?? 'No email',
                            style: AppDesignSystem.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Signed in with Google',
                            style: AppDesignSystem.bodyMedium.copyWith(color: AppDesignSystem.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Actions',
                style: AppDesignSystem.headlineMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('SIGN OUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.surfaceContainer,
                  foregroundColor: AppDesignSystem.onSurface,
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_forever),
                label: const Text('DELETE ACCOUNT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
              const Spacer(),
              const Center(
                child: Text(
                  'Haul Alerts v1.0',
                  style: TextStyle(color: AppDesignSystem.outline, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}