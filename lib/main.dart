import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/presentation/app_shell.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/auth/presentation/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  runApp(const ProviderScope(child: CinemuseApp()));
}

class CinemuseApp extends ConsumerWidget {
  const CinemuseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Cinemuse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.when(
        data: (user) => user != null ? const AppShell() : const AuthScreen(),
        loading: () => const Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, s) => const AuthScreen(),
      ),
    );
  }
}
