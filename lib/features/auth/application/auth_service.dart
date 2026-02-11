
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// User Model
class User {
  final String uid;
  final String email;
  final String idToken;

  User({required this.uid, required this.email, required this.idToken});
}

// Auth State Provider
final authProvider = StateNotifierProvider<AuthService, AsyncValue<User?>>((ref) {
  return AuthService();
});

// Auth Actions Provider (for UI to call sign in/out)
final authActionsProvider = Provider<AuthService>((ref) {
  return ref.watch(authProvider.notifier);
});

class AuthService extends StateNotifier<AsyncValue<User?>> {
  AuthService() : super(const AsyncValue.loading()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('auth_email');
      final uid = prefs.getString('auth_uid');

      if (email != null && uid != null) {
        state = AsyncValue.data(User(uid: uid, email: email, idToken: 'mock_token'));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock successful login
    final user = User(
      uid: 'mock_user_123',
      email: email,
      idToken: 'mock_token_abc123',
    );
    await _saveSession(user);
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 500));
    
    final user = User(
      uid: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      idToken: 'mock_token_xyz789',
    );
    await _saveSession(user);
  }
  
  Future<void> debugSignIn() async {
    return signIn('dev@cinemuse.com', 'password');
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', user.idToken);
    await prefs.setString('auth_email', user.email);
    await prefs.setString('auth_uid', user.uid);

    state = AsyncValue.data(user);
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AsyncValue.data(null);
  }

  void resetError() {
    if (state.hasError) {
      state = const AsyncValue.data(null);
    }
  }
}
