import 'package:cinemuse_app/core/error/supabase_error_handler.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth State Provider
final authProvider = StateNotifierProvider<AuthService, AsyncValue<User?>>((
  ref,
) {
  return AuthService(ref.watch(supabaseClientProvider));
});

class AuthService extends StateNotifier<AsyncValue<User?>> {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // 1. Set initial state used cached session
    final session = _supabaseClient.auth.currentSession;
    state = AsyncValue.data(session?.user);

    // 2. Listen to auth changes
    // On sign-out the session is null, so this also clears the user.
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
  }

  /// Signs in; the auth stream then sets the user.
  ///
  /// The state is not set to loading here: the app swaps `AuthScreen` for a
  /// spinner on loading, which would destroy the screen and its error
  /// message (REV-52). The screen shows its own spinner.
  Future<void> signIn(String email, String password) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw AuthException('Sign in failed');
      }
    } catch (e) {
      final appEx = SupabaseErrorHandler.handleError(e);
      state = AsyncValue.data(_supabaseClient.auth.currentUser);
      throw appEx;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _supabaseClient.auth.signOut();
  }

  void resetError() {
    if (state.hasError) {
      state = AsyncValue.data(_supabaseClient.auth.currentUser);
    }
  }
}
