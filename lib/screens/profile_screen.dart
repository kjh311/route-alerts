import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Icons, Material, MaterialPageRoute;
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('DELETE ACCOUNT?'),
        content: const Text(
          'Are you sure you want to permanently delete your account? This will delete all your routes and data. This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
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
            CupertinoPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('ERROR'),
              content: Text('Failed to delete account: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('PROFILE', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Color(0xFF1A1A1A),
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Account',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.person_crop_circle, color: Color(0xFFE67E22), size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userEmail ?? 'No email',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Signed in with Google',
                            style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Actions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _signOut,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.square_arrow_left, size: 20),
                      const SizedBox(width: 12),
                      Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0x11FF3B30),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _deleteAccount,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.delete, color: CupertinoColors.systemRed, size: 20),
                      const SizedBox(width: 12),
                      Text('DELETE ACCOUNT', style: TextStyle(color: CupertinoColors.systemRed, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
              const Center(
                child: Text(
                  'Haul Alerts v1.0',
                  style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}