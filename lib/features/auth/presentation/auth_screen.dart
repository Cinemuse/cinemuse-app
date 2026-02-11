import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  String? errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      final actions = ref.read(authActionsProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        if (isLogin) {
          await actions.signIn(email, password);
        } else {
          await actions.signUp(email, password);
        }
      } catch (e) {
        setState(() {
          errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error snackbar
    if (errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => errorMessage = null);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Logo
                  Image.asset(
                    'assets/wordmark-logo.png',
                    height: 48,
                    errorBuilder: (c, e, s) => const Text(
                      "CINEMUSE",
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: 2
                      )
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    isLogin ? 'Welcome Back' : 'Join CineMuse',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin 
                      ? 'Enter your credentials to access your account' 
                      : 'Create an account to start watching',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 32),

                  // E-mail Input
                   Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'EMAIL', 
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'hello@example.com',
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                   Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PASSWORD', 
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) => value != null && value.length >= 6 ? null : 'Password must be 6+ chars',
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : Text(isLogin ? 'Sign In' : 'Create Account'),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Toggle Login/Signup
                  TextButton(
                    onPressed: () {
                       setState(() => isLogin = !isLogin);
                    },
                    child: Text(
                      isLogin ? "Don't have an account?" : "Already have an account?",
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("OR", style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: AppTheme.border)),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Guest Button (Visual only)
                   SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Continue as Guest'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: null, // Disabled
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Debug Login
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.developer_mode, color: Colors.amber),
                      label: const Text('Debug Login', style: TextStyle(color: Colors.amber)),
                      onPressed: () {
                        ref.read(authActionsProvider).debugSignIn();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
