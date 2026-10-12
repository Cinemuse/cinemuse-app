import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/explore/presentation/pages/explore_screen.dart';
import 'package:cinemuse_app/features/navigation/presentation/navbar.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_hub.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/bottom_navbar.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/live_tv_screen.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/presentation/update_overlay.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/shared/widgets/error_toast.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // In NavTab order.
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

  void _handleBack({required bool canExitApp}) {
    final outcome = ref
        .read(backNavigationProvider.notifier)
        .handleBack(canExitApp: canExitApp);
    switch (outcome) {
      case BackOutcome.handled:
        break;
      case BackOutcome.confirmExit:
        AppSnackBar.show(
          context,
          message: AppLocalizations.of(context)!.shellPressBackAgainToExit,
          duration: BackNavigationNotifier.exitWindow,
        );
      case BackOutcome.exit:
        // Closes the Android activity; the app has nothing to await after it.
        unawaited(SystemNavigator.pop());
    }
  }

  void _onDestinationSelected(
    int index,
    GlobalKey<NavigatorState> shellNavigatorKey,
  ) {
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
    // One rule for the whole shell (REV-51): the navbar gets the same answer.
    final isCompact = Breakpoints.isCompact(context);
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
          // Only the Android Back button / gesture gets here.
          _handleBack(canExitApp: true);
        },
        child: Focus(
          autofocus: false,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.escape) {
              _handleBack(canExitApp: false);
              return KeyEventResult.handled;
            }
            // TV remote Back / gamepad B: same as the Android Back button.
            if (key == LogicalKeyboardKey.goBack ||
                key == LogicalKeyboardKey.gameButtonB) {
              _handleBack(
                canExitApp: defaultTargetPlatform == TargetPlatform.android,
              );
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            backgroundColor: Colors.black, // Match "bg-primary"
            bottomNavigationBar: isCompact
                ? AppBottomNavbar(
                    currentIndex: currentIndex,
                    onTap: (index) =>
                        _onDestinationSelected(index, shellNavigatorKey),
                  )
                : null,
            body: _buildBody(
              currentIndex: currentIndex,
              isCompact: isCompact,
              shellNavigatorKey: shellNavigatorKey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required int currentIndex,
    required bool isCompact,
    required GlobalKey<NavigatorState> shellNavigatorKey,
  }) {
    return Stack(
      children: [
        Column(
          children: [
            AppNavbar(
              currentIndex: currentIndex,
              isCompact: isCompact,
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
