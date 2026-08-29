import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_project_config.dart';
import '../cubits/mode_cubit.dart';

class SimpleAuthService {
  SimpleAuthService._();

  static final SimpleAuthService instance = SimpleAuthService._();

  static const String _username = 'djalil';
  static const String _authEmail = String.fromEnvironment(
    'SUPABASE_AUTH_EMAIL',
    defaultValue: '',
  );

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);

  /// True when the active Supabase session originated from a
  /// `passwordRecovery` event (the user clicked the link in the recovery
  /// email). The AuthGate listens to this and shows the Reset Password
  /// screen instead of the normal login flow.
  final ValueNotifier<bool> isPasswordRecovery = ValueNotifier<bool>(false);

  StreamSubscription<AuthState>? _authSubscription;

  bool get isConfigured =>
      SupabaseProjectConfig.isConfigured && _authEmail.isNotEmpty;
  bool _isAllowedSession(Session? session) =>
      session?.user.email?.toLowerCase() == _authEmail.toLowerCase();

  Future<void> initialize() async {
    // Login is gated on having BOTH Supabase configured AND a known
    // auth email. Password recovery only needs Supabase configured (the
    // user supplies the email themselves), so we still install the
    // auth-state listener whenever Supabase is configured even if login
    // isn't enabled.
    if (!SupabaseProjectConfig.isConfigured) {
      isLoggedIn.value = false;
      isPasswordRecovery.value = false;
      return;
    }

    // Inspect any session that is already present at boot (this is how a
    // Supabase recovery link works on the web: the SDK parses the URL
    // fragment during `Supabase.initialize` and emits a `passwordRecovery`
    // event right after, which our listener below will pick up).
    final initialSession = Supabase.instance.client.auth.currentSession;
    isLoggedIn.value = _isAllowedSession(initialSession);
    isPasswordRecovery.value = false;

    // Guard against duplicate listeners.
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) {
        final session = event.session;
        switch (event.event) {
          case AuthChangeEvent.passwordRecovery:
            // Stay on the Reset Password screen until the user successfully
            // submits a new password (or signs out).
            isPasswordRecovery.value = session != null;
            isLoggedIn.value = false;
            break;
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            isPasswordRecovery.value = false;
            isLoggedIn.value = _isAllowedSession(session);
            break;
          case AuthChangeEvent.signedOut:
            isPasswordRecovery.value = false;
            isLoggedIn.value = false;
            break;
          default:
            // For any other event, fall back to recomputing the login flag
            // and leaving the recovery flag untouched. The listener above
            // explicitly handles the only transitions that can flip the
            // recovery state.
            isLoggedIn.value = _isAllowedSession(session);
        }
      },
    );
  }

  Future<bool> login({
    required String username,
    required String password,
    AppMode mode = AppMode.online,
  }) async {
    if (username.trim() != _username) {
      return false;
    }

    if (mode == AppMode.offline) {
      if (password == 'Kiosque123@') {
        isLoggedIn.value = true;
        return true;
      }
      return false;
    }

    if (!isConfigured) {
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

  /// Sends a Supabase password-recovery email.
  ///
  /// Only requires the Supabase client to be configured (URL + anon key);
  /// the configured login email is irrelevant here because the user supplies
  /// the target email address themselves.
  Future<void> sendRecoveryEmail(String email) async {
    if (!SupabaseProjectConfig.isConfigured) {
      throw StateError('Supabase غير مهيأ');
    }
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _recoveryRedirectUrl(),
    );
  }

  /// Updates the password of the currently signed-in user (the recovery user).
  ///
  /// Only requires the Supabase client to be configured and an active
  /// session — the recovery session is established by the SDK when the
  /// recovery link is opened.
  Future<void> updatePassword(String newPassword) async {
    if (!SupabaseProjectConfig.isConfigured) {
      throw StateError('Supabase غير مهيأ');
    }
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> logout() async {
    if (!SupabaseProjectConfig.isConfigured) {
      isLoggedIn.value = false;
      isPasswordRecovery.value = false;
      return;
    }
    await Supabase.instance.client.auth.signOut();
    isPasswordRecovery.value = false;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  /// Returns the redirect URL used in the password-recovery email. For local
  /// Flutter Web development this defaults to `http://localhost:3000/`.
  static String _recoveryRedirectUrl() {
    const configured = String.fromEnvironment('SUPABASE_REDIRECT_URL');
    if (configured.isNotEmpty) return configured;
    return 'http://localhost:3000/';
  }
}
