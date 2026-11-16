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
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/navigation/application/back_navigation_notifier.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/bottom_navbar.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/live_tv/presentation/live_tv_screen.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/updates/application/update_required_provider.dart';
import 'package:cinemuse_app/features/updates/presentation/update_messages.dart';
import 'package:cinemuse_app/features/updates/presentation/update_required_screen.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_sync_service.dart';
import 'package:cinemuse_app/core/error/error_service.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  /// Stand-in tabs, so a test can check the shell without the real screens.
  @visibleForTesting
  final List<Widget>? tabsForTesting;

  const AppShell({super.key, this.tabsForTesting});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // In NavTab order.
  late final List<Widget> _screens =
      widget.tabsForTesting ??
      const [HomeScreen(), ExploreScreen(), LiveTvScreen(), ProfileHub()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    ref.read(navIndexProvider.notifier).set(index);
    final navigator = shellNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  /// The focus of the page opened over the tabs (a title page, Settings), or
  /// null when only the tabs are showing.
  FocusScopeNode? _openPageScope(GlobalKey<NavigatorState> shellNavigatorKey) {
    final navigator = shellNavigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return null;
    // Flutter takes the pages below the top one out of the arrow moves.
    for (final child in navigator.focusNode.children) {
      if (child is FocusScopeNode &&
          !child.skipTraversal &&
          child.canRequestFocus) {
        return child;
      }
    }
    return null;
  }

  /// Down from the navbar onto the open page: where the focus was on it, or
  /// its top item the first time.
  bool _focusOpenPage(GlobalKey<NavigatorState> shellNavigatorKey) {
    final scope = _openPageScope(shellNavigatorKey);
    if (scope == null) return false;
    if (scope.focusedChild != null) {
      scope.requestFocus();
    } else {
      scope.focusInDirection(TraversalDirection.down);
    }
    return true;
  }

  /// Up with nothing above on an open page goes to the navbar. The tabs
  /// wire Up themselves, so on a tab this only covers Up with nothing
  /// focused yet.
  KeyEventResult _onOpenPageKey(
    KeyEvent event, {
    required bool isCompact,
    required GlobalKey<NavigatorState> shellNavigatorKey,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowUp || isCompact) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    if (_openPageScope(shellNavigatorKey) == null) {
      return _focusTabTop(focused);
    }
    if (focused != null && focused.focusInDirection(TraversalDirection.up)) {
      return KeyEventResult.handled;
    }
    final focusNavbar = ref.read(topNavbarFocusActionProvider);
    if (focusNavbar == null) return KeyEventResult.ignored;
    _showPageTop(focused);
    focusNavbar();
    return KeyEventResult.handled;
  }

  /// Just after the app opens no item on the tab has the focus yet, and
  /// Flutter would answer Up with the tab's lowest item (Home's last row):
  /// it goes where Down from the navbar goes instead.
  KeyEventResult _focusTabTop(FocusNode? focused) {
    if (focused is! FocusScopeNode || focused.focusedChild != null) {
      return KeyEventResult.ignored;
    }
    final focusTab = ref.read(
      pageContentFocusActionsProvider,
    )[ref.read(navIndexProvider)];
    if (focusTab == null) return KeyEventResult.ignored;
    focusTab();
    return KeyEventResult.handled;
  }

  /// No stop is left above: this is the keys' only way back to the top of
  /// the page, its title or photo.
  void _showPageTop(FocusNode? focused) {
    final context = focused?.context;
    if (context == null) return;
    Scrollable.maybeOf(context, axis: Axis.vertical)?.position.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
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
        AppSnackBar.show(context, message: next.message, isError: true);
        // Consume the error so it doesn't re-trigger
        ref.read(errorServiceProvider.notifier).consume();
      }
    });

    final isUpdateRequired =
        ref.watch(updatesShownProvider) &&
        (ref.watch(updateRequiredProvider).value ?? false);
    return UpdateMessages(
      showsMessages: !isUpdateRequired,
      child: isUpdateRequired
          ? const UpdateRequiredScreen()
          : _buildShell(
              currentIndex: currentIndex,
              isCompact: isCompact,
              shellNavigatorKey: shellNavigatorKey,
            ),
    );
  }

  Widget _buildShell({
    required int currentIndex,
    required bool isCompact,
    required GlobalKey<NavigatorState> shellNavigatorKey,
  }) {
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
    return Column(
      children: [
        AppNavbar(
          currentIndex: currentIndex,
          isCompact: isCompact,
          onTap: (index) => _onDestinationSelected(index, shellNavigatorKey),
          onSettingsTap: () => _openSettings(shellNavigatorKey),
          onSearchTap: () => SearchOverlay.show(
            context,
            navigator: shellNavigatorKey.currentState,
          ),
          onFocusOpenPage: () => _focusOpenPage(shellNavigatorKey),
        ),
        Expanded(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) => _onOpenPageKey(
              event,
              isCompact: isCompact,
              shellNavigatorKey: shellNavigatorKey,
            ),
            child: _buildNavigator(shellNavigatorKey),
          ),
        ),
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
