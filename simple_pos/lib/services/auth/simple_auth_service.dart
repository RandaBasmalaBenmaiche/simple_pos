import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_project_config.dart';

class SimpleAuthService {
  SimpleAuthService._();

  static final SimpleAuthService instance = SimpleAuthService._();

  static const String _username = 'djalil';
  static const String _authEmail = String.fromEnvironment(
    'SUPABASE_AUTH_EMAIL',
    defaultValue: 'benmaichedjallil@gmail.com',
  );

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  StreamSubscription<AuthState>? _authSubscription;

  bool get isConfigured => SupabaseProjectConfig.isConfigured;
  bool _isAllowedSession(Session? session) =>
      session?.user.email?.toLowerCase() == _authEmail.toLowerCase();

  Future<void> initialize() async {
    if (!isConfigured) {
      isLoggedIn.value = false;
      return;
    }

    isLoggedIn.value = _isAllowedSession(
      Supabase.instance.client.auth.currentSession,
    );
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) {
        isLoggedIn.value = _isAllowedSession(event.session);
      },
    );
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (!isConfigured || username.trim() != _username) {
      return false;
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _authEmail,
        password: password,
      );
      return _isAllowedSession(Supabase.instance.client.auth.currentSession);
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    if (!isConfigured) {
      isLoggedIn.value = false;
      return;
    }
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
