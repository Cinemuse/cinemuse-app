import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_collections.dart';
import 'package:cinemuse_app/features/profile/presentation/profile_overview.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/profile_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileHub extends ConsumerStatefulWidget {
  const ProfileHub({super.key});

  @override
  ConsumerState<ProfileHub> createState() => _ProfileHubState();
}

class _ProfileHubState extends ConsumerState<ProfileHub> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 60, 
                  left: AppTheme.getResponsiveHorizontalPadding(context), 
                  right: AppTheme.getResponsiveHorizontalPadding(context), 
                  bottom: 0
                ),
                child: Column(
                  children: [
                    const ProfileHero(),
                    const SizedBox(height: 24),
                    // Navigation Tabs
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: AppTheme.accent,
                      indicatorWeight: 2,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      dividerColor: Colors.transparent,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'OVERVIEW'),
                        Tab(text: 'COLLECTIONS'),
                        Tab(text: 'ACTIVITY'),
                      ],
                    ),
                    const Divider(height: 1, color: Colors.white24),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            ProfileOverview(),
            ProfileCollections(),
            Center(child: Text("Activity Coming Soon", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}
