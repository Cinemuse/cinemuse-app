import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/explore/presentation/pages/explore_screen.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_hub.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';


class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const Center(child: Text("Live TV (Todo)")),
    const ProfileHub(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Match "bg-primary"
      body: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: IndexedStack(
              index: currentIndex,
              children: _screens,
            ),
          ),
          
          // Top Navbar (Floating)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppNavbar(
              currentIndex: currentIndex,
              onTap: (index) {
                ref.read(navIndexProvider.notifier).state = index;
              },
              onSettingsTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              onLogoutTap: () {
                ref.read(authProvider.notifier).signOut();
              },
              onSearchTap: () => SearchOverlay.show(context),
            ),
          ),
        ],
      ),
    );
  }
}
