import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_hero.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_overview.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_collections.dart';

class ProfileHub extends ConsumerStatefulWidget {
  const ProfileHub({super.key});

  @override
  ConsumerState<ProfileHub> createState() => _ProfileHubState();
}

class _ProfileHubState extends ConsumerState<ProfileHub>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusNode _tabBarFocusNode = FocusNode(debugLabel: 'ProfileTabBar');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(pageContentFocusActionsProvider.notifier).update(
          (map) => {
            ...map,
            3: () {
              _tabBarFocusNode.requestFocus();
            },
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tabBarFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.secondary,
        onRefresh: () async {
          final user = ref.read(authProvider).value;
          if (user != null) {
            await Future.wait([
              ref.read(watchHistoryRepositoryProvider).syncWatchHistory(user.id),
              ref.read(listsRepositoryProvider).syncUserLists(user.id),
            ]).catchError((_) => []);
          }

          ref.invalidate(userListsProvider);
        },
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (isOffline) ...[
                    SizedBox(height: 40),
                    OfflineBanner(
                      onRetry: () => ref.invalidate(connectivityProvider),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    SizedBox(height: 60),
                  ],
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.getResponsiveHorizontalPadding(
                        context,
                      ),
                    ),
                    child: Column(
                      children: [
                        const ProfileHero(),
                        const SizedBox(height: 24),
                        // Navigation Tabs
                        Focus(
                          focusNode: _tabBarFocusNode,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              final focusNavbar = ref.read(topNavbarFocusActionProvider);
                              if (focusNavbar != null) {
                                focusNavbar();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicatorColor: AppTheme.accent,
                            indicatorWeight: 2,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            dividerColor: Colors.transparent,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              Tab(text: l10n.profileOverview),
                              Tab(text: l10n.profileCollections),
                              Tab(text: l10n.profileActivity),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            const ProfileOverview(),
            const ProfileCollections(),
            Center(
              child: Text(
                l10n.profileActivityComingSoon,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
