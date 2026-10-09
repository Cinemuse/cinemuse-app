import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/explore/presentation/pages/explore_screen.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_hub.dart';
import 'package:cinemuse_app/core/presentation/navigation_providers.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/bottom_navbar.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/live_tv_screen.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/core/services/updates/update_service.dart';
import 'package:cinemuse_app/core/presentation/widgets/update_overlay.dart';
import 'package:cinemuse_app/core/services/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/shared/widgets/error_toast.dart';

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
      // Background sync for anime mappings
      ref.read(animeMappingSyncServiceProvider).checkAndSync();
    });
  }

  void _handleBackNavigation() {
    final shellNavigatorKey = ref.read(shellNavigatorKeyProvider);
    final navigator = shellNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }

    // If currently in Live TV full-window mode, restore split mode
    if (ref.read(navIndexProvider) == 2 &&
        ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow) {
      ref.read(liveTvViewModeProvider.notifier).state = LiveTvViewMode.split;
      return;
    }
  }

  void _onDestinationSelected(
    int index,
    GlobalKey<NavigatorState> shellNavigatorKey,
  ) {
    if (ref.read(liveTvViewModeProvider) == LiveTvViewMode.fullWindow) {
      ref.read(liveTvViewModeProvider.notifier).state = LiveTvViewMode.split;
    }
    ref.read(navIndexProvider.notifier).state = index;
    final navigator = shellNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _openSettings(GlobalKey<NavigatorState> shellNavigatorKey) {
    shellNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final shellNavigatorKey = ref.watch(shellNavigatorKeyProvider);

    // Global Error Listener
    ref.listen(errorServiceProvider, (previous, next) {
      if (next != null) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: ErrorToast(
              message: next.message,
              type: next.type,
              onDismiss: scaffoldMessenger.hideCurrentSnackBar,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            padding: EdgeInsets.zero,
          ),
        );
        // Consume the error so it doesn't re-trigger
        ref.read(errorServiceProvider.notifier).consume();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: Focus(
          autofocus: false,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonB ||
                  event.logicalKey == LogicalKeyboardKey.goBack) {
                _handleBackNavigation();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            backgroundColor: Colors.black, // Match "bg-primary"
            bottomNavigationBar: isMobile
                ? AppBottomNavbar(
                    currentIndex: currentIndex,
                    onTap: (index) =>
                        _onDestinationSelected(index, shellNavigatorKey),
                  )
                : null,
            body: isMobile
                ? _buildMobileBody(shellNavigatorKey)
                : _buildWidescreenBody(
                    currentIndex: currentIndex,
                    shellNavigatorKey: shellNavigatorKey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(GlobalKey<NavigatorState> shellNavigatorKey) {
    return Stack(
      children: [
        _buildNavigator(shellNavigatorKey),
        const Positioned.fill(child: UpdateOverlay()),
      ],
    );
  }

  Widget _buildWidescreenBody({
    required int currentIndex,
    required GlobalKey<NavigatorState> shellNavigatorKey,
  }) {
    final isLiveTvFullWindow =
        currentIndex == 2 &&
        ref.watch(liveTvViewModeProvider) == LiveTvViewMode.fullWindow;

    return Stack(
      children: [
        Column(
          children: [
            if (!isLiveTvFullWindow)
              AppNavbar(
                currentIndex: currentIndex,
                onTap: (index) =>
                    _onDestinationSelected(index, shellNavigatorKey),
                onSettingsTap: () => _openSettings(shellNavigatorKey),
                onLogoutTap: () => ref.read(authProvider.notifier).signOut(),
                onSearchTap: () => SearchOverlay.show(
                  context,
                  navigator: shellNavigatorKey.currentState,
                ),
              ),
            Expanded(child: _buildNavigator(shellNavigatorKey)),
          ],
        ),
        const Positioned.fill(child: UpdateOverlay()),
      ],
    );
  }

  Widget _buildNavigator(GlobalKey<NavigatorState> shellNavigatorKey) {
    return Navigator(
      key: shellNavigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => Consumer(
            builder: (context, ref, child) {
              final index = ref.watch(navIndexProvider);
              return IndexedStack(index: index, children: _screens);
            },
          ),
        );
      },
    );
  }
}
