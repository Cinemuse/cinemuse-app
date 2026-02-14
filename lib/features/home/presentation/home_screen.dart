import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/media/presentation/details/media_details_screen.dart';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Section (Trending #1)
            trendingAsync.when(
              data: (data) => _HeroSection(media: data.isNotEmpty ? data[0] : null),
              loading: () => const SizedBox(height: 600, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(height: 500, child: Center(child: Text('Error loading features'))),
            ),
            
            const SizedBox(height: 20),

            // 2. Trending List
            _MediaRow(title: "Trending Now", asyncData: trendingAsync, skipFirst: true),

            const SizedBox(height: 30),

            // 3. Continue Watching (Supabase)
            const _ContinueWatchingRow(), // New widget

            const SizedBox(height: 30),

            // 5. Popular Movies
            _MediaRow(title: "Popular Movies", asyncData: popularMoviesAsync),

            const SizedBox(height: 30),

            // 5. Popular Series
            _MediaRow(title: "Popular Series", asyncData: popularSeriesAsync),

            const SizedBox(height: 50),
             
             // Manual Entry (Tool)
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
             const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Map<String, dynamic>? media;
  const _HeroSection({this.media});

  @override
  Widget build(BuildContext context) {
    if (media == null) return const SizedBox.shrink();
    final backdrop = media!['backdrop_path'];
    final imageUrl = backdrop != null ? "https://image.tmdb.org/t/p/original$backdrop" : null;
    final title = media!['title'] ?? media!['name'] ?? 'Unknown';
    final overview = media!['overview'] ?? '';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          if (imageUrl != null)
             Image.network(
              imageUrl, 
              fit: BoxFit.cover, 
              alignment: Alignment.topCenter,
              errorBuilder: (c, e, s) => Container(color: AppTheme.surface),
            )
          else
            Container(color: AppTheme.surface),
          
          // Gradients (Matching web styles)
          // Left to Right (Primary to Transparent)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                   Color(0xFF0f0518), // AppTheme.primary
                   Color(0x660f0518),
                   Colors.transparent,
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          
          // Bottom to Top (Primary to Transparent)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                   Color(0xFF0f0518),
                   Color(0x990f0518),
                   Colors.transparent,
                ],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // Content
          Positioned(
            left: 32,
            bottom: 64,
            right: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Text(
                  "FEATURED",
                  style: TextStyle(
                    color: Color(0xFFd946ef), // Accent
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                 Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis, 
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 600,
                  child: Text(
                    overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                     ElevatedButton.icon(
                      onPressed: () {
                         // Play Logic
                         Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MediaDetailsScreen(
                                mediaId: media!['id'].toString(), 
                                mediaType: media!['media_type'] ?? 'movie',
                              ),
                            ),
                          );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text("Play Now"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFd946ef), // Accent
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 10,
                        shadowColor: const Color(0xFFd946ef).withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline_rounded, size: 28),
                      label: const Text("More Info"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> asyncData;
  final bool skipFirst;

  const _MediaRow({required this.title, required this.asyncData, this.skipFirst = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240, // Height for card + text
          child: asyncData.when(
            data: (data) {
              final list = skipFirst && data.isNotEmpty ? data.skip(1).toList() : data;
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (c, i) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final poster = item['poster_path'];
                  final imageUrl = poster != null ? "https://image.tmdb.org/t/p/w500$poster" : null;
                  final title = item['title'] ?? item['name'] ?? 'Unknown';
                  final date = item['release_date'] ?? item['first_air_date'] ?? '';
                  final year = date.toString().split('-').first;

                  return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MediaDetailsScreen(
                            mediaId: item['id'].toString(), 
                            mediaType: item['media_type'] ?? (title.contains("Series") ? "tv" : "movie"),
                          ),
                        ));
                     },
                    child: SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.surface,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: imageUrl == null ? const Center(child: Icon(Icons.movie, color: Colors.white24)) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            year,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
             loading: () => const Center(child: CircularProgressIndicator()),
             error: (e, s) => const Center(child: Text("Error", style: TextStyle(color: Colors.red))),
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingRow extends ConsumerWidget {
  const _ContinueWatchingRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(continueWatchingProvider);

    return historyAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Text(
                    "Continue Watching",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ),
            SizedBox(
              height: 180, // Height for card + text
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (c, i) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final historyItem = items[index];
                  final media = historyItem.media;
                  final title = media?.title ?? 'Unknown';
                  final percentage = (historyItem.totalDuration != null && historyItem.totalDuration! > 0)
                      ? (historyItem.progressSeconds / historyItem.totalDuration!)
                      : 0.0;
                  
                  final backdrop = media?.backdropPath;
                  final imageUrl = backdrop != null ? "https://image.tmdb.org/t/p/w500$backdrop" : null;
                  
                  return GestureDetector(
                    onTap: () {
                         Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MediaDetailsScreen(
                            mediaId: historyItem.tmdbId.toString(), 
                            mediaType: historyItem.mediaType.name,
                          ),
                        ));
                    },
                    child: SizedBox(
                      width: 280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Image
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[900],
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                image: imageUrl != null 
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                                      )
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                   // Center Play Icon (Overlay)
                                   Center(
                                     child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 48),
                                   ),
                                   
                                   // Progress Bar
                                   Positioned(
                                     bottom: 0, 
                                     left: 0, 
                                     right: 0,
                                     child: LinearProgressIndicator(
                                       value: percentage,
                                       backgroundColor: Colors.white.withOpacity(0.2),
                                       valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                       minHeight: 4,
                                     ),
                                   )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Type info
                          Text(
                             media?.mediaType == 'episode' 
                              ? "Episode" // TODO: Add Season/Episode info to cache/history
                              : "Movie",
                             style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(), // Don't show loading for continue watching to avoid jump
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
