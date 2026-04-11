import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero_section.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/media_row.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/system/connectivity_service.dart';
import 'package:cinemuse_app/shared/widgets/offline_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trendingAsync = ref.watch(trendingProvider);
    final popularMoviesAsync = ref.watch(popularMoviesProvider);
    final popularSeriesAsync = ref.watch(popularSeriesProvider);
    final connectivity = ref.watch(connectivityProvider);
    
    final isOffline = connectivity.valueOrNull == ConnectivityResult.none;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (!isOffline) ...[
              // 1. Hero Section (Trending #1)
              RepaintBoundary(
                child: trendingAsync.when(
                  data: (data) => HeroSection(media: data.isNotEmpty ? data[0] : null),
                  loading: () => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75, 
                    child: const Center(child: CircularProgressIndicator())
                  ),
                  error: (err, stack) {
                    final mapped = ref.read(errorMapperProvider).map(err);
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6, 
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: ErrorCard(
                            message: mapped.message,
                            hint: mapped.hint,
                            type: mapped.type,
                            onRetry: () => ref.refresh(trendingProvider),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Offline Spacer to account for missing Hero height
              const SizedBox(height: 40),
              OfflineBanner(
                onRetry: () => ref.invalidate(connectivityProvider),
              ),
            ],
            
            // 2. Content
            Transform.translate(
              offset: Offset(0, isOffline ? 0 : -60), // No overlap offset if offline
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Continue Watching
                  RepaintBoundary(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: const ContinueWatchingRow(),
                    ),
                  ),
                  
                  if (!isOffline) ...[
                    const SizedBox(height: 20),
                    // Trending List
                    RepaintBoundary(
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: MediaRow(title: l10n.homeTrendingNow, asyncData: trendingAsync, skipFirst: true),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Popular Movies
                    RepaintBoundary(
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: MediaRow(title: l10n.homePopularMovies, asyncData: popularMoviesAsync),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Popular Series
                    RepaintBoundary(
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: MediaRow(title: l10n.homePopularSeries, asyncData: popularSeriesAsync),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 50),
                  const SizedBox(height: 40), // Standard bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
