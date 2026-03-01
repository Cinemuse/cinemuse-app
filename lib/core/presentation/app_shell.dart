import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/explore/presentation/pages/explore_screen.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_hub.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/intents.dart';
import 'package:cinemuse_app/core/presentation/navigation_providers.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/bottom_navbar.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/live_tv_screen.dart';
import 'package:cinemuse_app/core/services/update_service.dart';
import 'package:cinemuse_app/core/presentation/widgets/update_overlay.dart';



class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const LiveTvScreen(),
    const ProfileHub(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {

    final currentIndex = ref.watch(navIndexProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final shellNavigatorKey = ref.watch(shellNavigatorKeyProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = shellNavigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Match "bg-primary"
        body: Stack(
          children: [
            // Main Content Area with Nested Navigator
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 80, // Space for top navbar
                  bottom: isMobile ? 80 : 0, // Space for bottom navbar
                ),
                child: Navigator(
                  key: shellNavigatorKey,
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (context) => Consumer(
                        builder: (context, ref, child) {
                          final index = ref.watch(navIndexProvider);
                          return IndexedStack(
                            index: index,
                            children: _screens,
                          );
                        },
                      ),
                    );
                  },
                ),
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
                  // Reset nested navigator when switching tabs? 
                  // For now, just change index.
                  ref.read(navIndexProvider.notifier).state = index;
                  // If we want to reset the tab when tapping its icon:
                  final navigator = shellNavigatorKey.currentState;
                  if (navigator != null && navigator.canPop()) {
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                onSettingsTap: () {
                  shellNavigatorKey.currentState?.push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                onLogoutTap: () {
                  ref.read(authProvider.notifier).signOut();
                },
                onSearchTap: () => SearchOverlay.show(context, navigator: shellNavigatorKey.currentState),
              ),
            ),

            // Bottom Navbar (Floating) - Visible only on Mobile
            if (isMobile)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AppBottomNavbar(
                  currentIndex: currentIndex,
                  onTap: (index) {
                    ref.read(navIndexProvider.notifier).state = index;
                    final navigator = shellNavigatorKey.currentState;
                    if (navigator != null && navigator.canPop()) {
                      navigator.popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ),

            // Update Notification Overlay
            const Positioned(
              top: 80, // Just below the top navbar
              left: 0,
              right: 0,
              child: UpdateOverlay(),
            ),
          ],
        ),

      ),
    );
  }
}
