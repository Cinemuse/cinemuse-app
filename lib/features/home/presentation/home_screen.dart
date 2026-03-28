
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero_section.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/media_row.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
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
            
            // 2. Content with negative margin to overlap Hero
            Transform.translate(
              offset: const Offset(0, -60), // Pull up to overlap hero gradient
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
