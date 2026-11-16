import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Kept alive: the signed-in user is needed for the whole session.
final authProvider = NotifierProvider<AuthService, AsyncValue<User?>>(
  AuthService.new,
);

class AuthService extends Notifier<AsyncValue<User?>> {
  SupabaseClient get _supabaseClient => ref.read(supabaseClientProvider);

  @override
  AsyncValue<User?> build() {
    final client = ref.watch(supabaseClientProvider);
    // On sign-out the session is null, so this also clears the user.
    final subscription = client.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
    ref.onDispose(subscription.cancel);
    // The cached session, until the auth stream sends one.
    return AsyncValue.data(client.auth.currentSession?.user);
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
    } catch (e, st) {
      state = AsyncValue.data(_supabaseClient.auth.currentUser);
      Error.throwWithStackTrace(supabaseErrorToFailure(e, st), st);
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
