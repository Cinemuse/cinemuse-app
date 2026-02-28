import 'package:cinemuse_app/core/error/supabase_error_handler.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth State Provider
final authProvider = StateNotifierProvider<AuthService, AsyncValue<User?>>((ref) {
  return AuthService();
});

// Auth Actions Provider
final authActionsProvider = Provider<AuthService>((ref) {
  return ref.watch(authProvider.notifier);
});

class AuthService extends StateNotifier<AsyncValue<User?>> {
  AuthService() : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // 1. Set initial state used cached session
    final session = supabase.auth.currentSession;
    state = AsyncValue.data(session?.user);

    // 2. Listen to auth changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      state = AsyncValue.data(session?.user);
      
      if (event == AuthChangeEvent.signedOut) {
        state = const AsyncValue.data(null);
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw 'Sign in failed';
      }
    } catch (e, st) {
      final appEx = SupabaseErrorHandler.handleError(e);
      state = AsyncValue.data(supabase.auth.currentUser);
      throw appEx;
    }
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw 'Sign up failed';
      }
    } catch (e, st) {
      final appEx = SupabaseErrorHandler.handleError(e);
      state = AsyncValue.data(supabase.auth.currentUser); 
      throw appEx;
    }
  }
  
  Future<void> debugSignIn() async {
    // Not applicable with real auth usually, or use a hardcoded test account
    // For now, let's remove or implement with a real test account if user wants
    state = const AsyncValue.loading();
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await supabase.auth.signOut();
  }

  void resetError() {
    if (state.hasError) {
      state = AsyncValue.data(supabase.auth.currentUser);
    }
  }
}
