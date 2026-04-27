import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _webNonce;

  /// Initializes GoogleSignIn based on the platform
  Future<void> init() async {
    // 1. Generate persistent raw nonce for web
    if (kIsWeb) {
      _webNonce = _supabase.auth.generateRawNonce();
    }

    // 2. Mandatory initialization
    if (kIsWeb) {
      final hashedNonce = sha256.convert(utf8.encode(_webNonce!)).toString();
      await GoogleSignIn.instance.initialize(
        clientId: AppConstants.googleWebClientId,
        nonce: hashedNonce,
      );
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConstants.googleWebClientId,
      );
    }

    // 3. Listen to user changes to handle background authentication
    GoogleSignIn.instance.authenticationEvents.listen((GoogleSignInAuthenticationEvent event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        try {
          await _handleSupabaseAuth(event.user);
        } catch (e) {
          debugPrint('DEBUG: Background Supabase Auth Error: $e');
        }
      }
    });

    // 4. Attempt silent sign-in for existing sessions
    unawaited(GoogleSignIn.instance.attemptLightweightAuthentication());
  }

  /// Internal helper to complete Supabase auth after Google login
  Future<AuthResponse> _handleSupabaseAuth(GoogleSignInAccount googleUser) async {
    // Token Retrieval (v7.2.0 Pattern)
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    // Use authorizeScopes to get the accessToken
    final List<String> scopes = ['email', 'profile'];
    final GoogleSignInClientAuthorization authorization = await googleUser.authorizationClient.authorizeScopes(scopes);
    final String? accessToken = authorization.accessToken;

    if (idToken == null || (!kIsWeb && accessToken == null)) {
      throw 'Missing tokens (idToken: $idToken, accessToken: $accessToken)';
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
      nonce: kIsWeb ? _webNonce : null,
    );
  }

  /// Helper to get the Web branded button widget
  Widget buildWebButton() {
    if (kIsWeb) {
      try {
        return (GoogleSignInPlatform.instance as dynamic).renderButton();
      } catch (e) {
        debugPrint('DEBUG: Failed to render Google button: $e');
      }
    }
    return const SizedBox.shrink();
  }

  /// Programmatic authentication (Mainly for Mobile or specific Web flows)
  Future<AuthResponse> authenticate() async {
    // 1. Web Safety Check
    if (kIsWeb) {
      throw 'Programmatic authenticate() is not supported on Web. Please use the branded button via buildWebButton().';
    }

    // 2. Attempt to sign in with Google
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
    
    // 3. Complete Supabase Auth
    return await _handleSupabaseAuth(googleUser);
  }

  /// Sign out from both Google and Supabase
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _supabase.auth.signOut();
  }
}
