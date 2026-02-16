
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/continue_watching_row.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero_section.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/media_row.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _idController = TextEditingController(text: 'tt1375666'); 

  @override
  Widget build(BuildContext context) {
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
            trendingAsync.when(
              data: (data) => HeroSection(media: data.isNotEmpty ? data[0] : null),
              loading: () => SizedBox(
                height: MediaQuery.of(context).size.height * 0.75, 
                child: const Center(child: CircularProgressIndicator())
              ),
              error: (err, stack) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.6, 
                child: const Center(child: Text('Error loading features'))
              ),
            ),
            
            // 2. Content with negative margin to overlap Hero
            Transform.translate(
              offset: const Offset(0, -60), // Pull up to overlap hero gradient
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Continue Watching
                  FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: const ContinueWatchingRow(),
                  ),
                  const SizedBox(height: 20),

                  // Trending List
                  FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: MediaRow(title: "Trending Now", asyncData: trendingAsync, skipFirst: true),
                  ),
                  const SizedBox(height: 30),

                  // Popular Movies
                  FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: MediaRow(title: "Popular Movies", asyncData: popularMoviesAsync),
                  ),
                  const SizedBox(height: 30),

                  // Popular Series
                  FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: MediaRow(title: "Popular Series", asyncData: popularSeriesAsync),
                  ),
                  const SizedBox(height: 50),
                   
                   // Manual Entry (Tool) - Kept for dev parity
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DEV TOOLS", style: GoogleFonts.outfit(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                         Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                 child: TextField(
                                  controller: _idController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    hintText: 'TMDB/IMDB ID',
                                    hintStyle: TextStyle(color: Colors.white30),
                                    labelText: "Test Playback ID",
                                    labelStyle: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text("Test Play", style: TextStyle(color: Colors.white)),
                                onPressed: () {
                                   if (_idController.text.isNotEmpty) {
                                      Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => VideoPlayerScreen(queryId: _idController.text.trim(), type: 'movie'),
                                      ));
                                   }
                                },
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom padding for scrolling
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
