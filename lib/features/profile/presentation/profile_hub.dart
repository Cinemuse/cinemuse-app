import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/refresh_user_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_hero.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_tab_bar.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_overview.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_collections.dart';

/// Profile as one page: the hero, the tab names, then the selected tab's
/// content, in one scroll view with one scrollbar. The tabs only swap the
/// content (REV-239: a [TabBarView] in a [NestedScrollView] attached both
/// tabs to one controller, and the desktop scrollbar asserted).
class ProfileHub extends ConsumerStatefulWidget {
  const ProfileHub({super.key});

  @override
  ConsumerState<ProfileHub> createState() => _ProfileHubState();
}

class _ProfileHubState extends ConsumerState<ProfileHub> {
  static const _tabCount = 2;

  /// A sideways touch swipe faster than this switches tab.
  static const _swipeVelocity = 300.0;

  final _scrollController = ScrollController();
  final _tabBarKey = GlobalKey();
  final _tabFocusNodes = List.generate(
    _tabCount,
    (i) => FocusNode(debugLabel: 'ProfileTab$i'),
  );
  // Holds the tab's content, to tell Up inside it from Up out of it.
  final _contentFocusNode = FocusNode(
    debugLabel: 'ProfileTabContent',
    canRequestFocus: false,
    skipTraversal: true,
  );
  int _tabIndex = 0;

  /// The side the new tab slides in from: 1 = right, -1 = left.
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(pageContentFocusActionsProvider.notifier)
            .update(
              (map) => {
                ...map,
                NavTab.profile: () => _tabFocusNodes[_tabIndex].requestFocus(),
              },
            );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contentFocusNode.dispose();
    for (final node in _tabFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tabIndex || index < 0 || index >= _tabCount) return;
    _bringTabBarToTop();
    setState(() {
      _slideDirection = index > _tabIndex ? 1 : -1;
      _tabIndex = index;
    });
  }

  /// When the page is scrolled past the tab names, puts them at the top of
  /// the screen, so the new tab shows from its start.
  void _bringTabBarToTop() {
    final tabBar = _tabBarKey.currentContext?.findRenderObject();
    if (tabBar == null || !_scrollController.hasClients) return;
    final top = RenderAbstractViewport.of(
      tabBar,
    ).getOffsetToReveal(tabBar, 0).offset;
    if (_scrollController.offset > top) _scrollController.jumpTo(top);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _swipeVelocity) return;
    // A swipe to the left brings the next tab.
    _selectTab(_tabIndex + (velocity < 0 ? 1 : -1));
  }

  KeyEventResult _onTabKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Past the first or last tab name there is nothing: Flutter would jump
    // to the nearest item on that side, often an agenda entry off the screen.
    if ((key == LogicalKeyboardKey.arrowLeft && node == _tabFocusNodes.first) ||
        (key == LogicalKeyboardKey.arrowRight && node == _tabFocusNodes.last)) {
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowUp) return KeyEventResult.ignored;
    final focusNavbar = ref.read(topNavbarFocusActionProvider);
    if (focusNavbar == null) return KeyEventResult.ignored;
    focusNavbar();
    return KeyEventResult.handled;
  }

  /// Up with nothing above it in the tab's content goes to the tab being
  /// shown: Flutter picked the nearest tab name, often the other one.
  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return KeyEventResult.ignored;
    // Only stops in line with it: the agenda column beside the rows starts
    // higher up, and Up must not count it.
    final here = focused.rect;
    final hasStopAbove = _contentFocusNode.traversalDescendants.any(
      (other) =>
          other != focused &&
          other.rect.center.dy < here.top &&
          other.rect.left < here.right &&
          other.rect.right > here.left,
    );
    if (hasStopAbove) return KeyEventResult.ignored;
    _tabFocusNodes[_tabIndex].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.value == ConnectivityResult.none;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.secondary,
        onRefresh: () async {
          await refreshUserData(context, ref);

          ref.invalidate(userListsProvider);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                isOffline: isOffline,
                onRetry: () => ref.invalidate(connectivityProvider),
                tabBar: ProfileTabBar(
                  key: _tabBarKey,
                  labels: [l10n.profileOverview, l10n.profileCollections],
                  selectedIndex: _tabIndex,
                  onSelected: _selectTab,
                  focusNodes: _tabFocusNodes,
                  onKeyEvent: _onTabKey,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Focus(
                focusNode: _contentFocusNode,
                onKeyEvent: _onContentKey,
                child: _ProfileTabContent(
                  index: _tabIndex,
                  slideDirection: _slideDirection,
                  onSwipe: _onSwipe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final bool isOffline;
  final VoidCallback onRetry;
  final Widget tabBar;

  const _ProfileHeader({
    required this.isOffline,
    required this.onRetry,
    required this.tabBar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isOffline) ...[
          const SizedBox(height: 40),
          OfflineBanner(onRetry: onRetry),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 60),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.getResponsiveHorizontalPadding(context),
          ),
          child: Column(
            children: [
              const ProfileHero(),
              const SizedBox(height: 24),
              tabBar,
              const Divider(height: 1, color: Colors.white24),
            ],
          ),
        ),
      ],
    );
  }
}

/// The selected tab's content. A quick sideways swipe on a touch screen
/// switches tab; the new content slides in briefly (it does not follow the
/// finger).
class _ProfileTabContent extends StatelessWidget {
  final int index;
  final int slideDirection;
  final GestureDragEndCallback onSwipe;

  const _ProfileTabContent({
    required this.index,
    required this.slideDirection,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(index);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: const {PointerDeviceKind.touch},
      onHorizontalDragEnd: onSwipe,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          // The old tab leaves on the side opposite to where the new one
          // comes from.
          final side = child.key == current ? slideDirection : -slideDirection;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(0.08 * side, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: current,
          child: index == 0
              ? const ProfileOverview()
              : const ProfileCollections(),
        ),
      ),
    );
  }
}
