import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/navigation/navbar.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/settings/presentation/settings_screen.dart';
import 'package:cinemuse_app/features/search/presentation/search_overlay.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

final personDetailsProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, id) async {
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.getPersonDetails(id);
});

class PersonDetailsScreen extends ConsumerStatefulWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends ConsumerState<PersonDetailsScreen> {
  int _visibleCredits = 50;
  bool _showHidden = false;

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(personDetailsProvider(widget.personId));
    final watchHistoryAsync = ref.watch(watchHistoryStoreProvider);
    final l10n = AppLocalizations.of(context)!;

    final responsivePadding = AppTheme.getResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: detailsAsync.when(
        data: (details) {
          if (details == null) return Center(child: Text(l10n.commonError));

          final watchHistory = watchHistoryAsync.value ?? {};
          return _PersonDetailsContent(
            details: details,
            watchHistory: watchHistory,
            responsivePadding: responsivePadding,
            visibleCredits: _visibleCredits,
            showHidden: _showHidden,
            onShowMore: () => setState(() => _visibleCredits += 50),
            onToggleHidden: () => setState(() => _showHidden = !_showHidden),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (err, _) => Center(child: Text(l10n.detailsErrorLoading(err.toString()))),
      ),
    );
  }
}

class _PersonDetailsContent extends ConsumerWidget {
  final Map<String, dynamic> details;
  final Map<String, dynamic> watchHistory;
  final double responsivePadding;
  final int visibleCredits;
  final bool showHidden;
  final VoidCallback onShowMore;
  final VoidCallback onToggleHidden;

  const _PersonDetailsContent({
    required this.details,
    required this.watchHistory,
    required this.responsivePadding,
    required this.visibleCredits,
    required this.showHidden,
    required this.onShowMore,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final String name = details['name'] ?? 'Unknown';
    final String? profilePath = details['profile_path'];
    final String? biography = details['biography'];
    final String? birthday = details['birthday'];
    final String? placeOfBirth = details['place_of_birth'];

    // Process Credits
    final cast = details['combined_credits']?['cast'] as List<dynamic>? ?? [];
    final crew = details['combined_credits']?['crew'] as List<dynamic>? ?? [];
    
    // Seen Stats Calculation
    int watchedCount = 0;
    int totalReleased = 0;
    final now = DateTime.now();

    final allCredits = [...cast, ...crew];
    final uniqueCreditsMap = <int, Map<String, dynamic>>{};
    
    for (final item in allCredits) {
      final id = item['id'] as int;
      if (!uniqueCreditsMap.containsKey(id)) {
        uniqueCreditsMap[id] = item;
        
        final dateStr = item['release_date'] ?? item['first_air_date'];
        if (dateStr != null && dateStr.isNotEmpty) {
          final releaseDate = DateTime.tryParse(dateStr);
          if (releaseDate != null && releaseDate.isBefore(now)) {
            totalReleased++;
            if (watchHistory.containsKey(id.toString())) {
              watchedCount++;
            }
          }
        }
      }
    }

    final watchedPercent = totalReleased > 0 ? (watchedCount / totalReleased * 100).round() : 0;

    // Known For
    final knownFor = List<Map<String, dynamic>>.from(cast)
      ..sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));
    final topKnownFor = knownFor.take(10).toList();

    // Filmography Processing
    var filmography = uniqueCreditsMap.values.toList();
    
    // Sort Date DESC
    filmography.sort((a, b) {
      final dateA = a['release_date'] ?? a['first_air_date'] ?? '0000-00-00';
      final dateB = b['release_date'] ?? b['first_air_date'] ?? '0000-00-00';
      return dateB.compareTo(dateA);
    });

    if (!showHidden) {
      const excludedGenres = {99, 10763, 10764, 10767};
      const excludedKeywords = ['academy awards', 'golden globe', 'oscar', 'grammy', 'emmy', 'mtv movie awards', 'bafta', 'award'];
      
      filmography = filmography.where((item) {
        final genreIds = (item['genre_ids'] as List<dynamic>?)?.cast<int>() ?? [];
        final hasExcludedGenre = genreIds.any((id) => excludedGenres.contains(id));
        
        final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
        final hasExcludedKeyword = excludedKeywords.any((kw) => title.contains(kw));
        
        return !hasExcludedGenre && !hasExcludedKeyword;
      }).toList();
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: responsivePadding, vertical: 32 + 100), // Added top padding for navbar
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Section: Info + Image
                    Wrap(
                      spacing: 48,
                      runSpacing: 32,
                      children: [
                        // Profile Image
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: profilePath != null
                                  ? CachedNetworkImage(
                                      imageUrl: 'https://image.tmdb.org/t/p/w500$profilePath',
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/cast_placeholder.png',
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ),
                        // Details
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back Button
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: AppBackButton(
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ),
                              Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (birthday != null)
                                _InfoRow(icon: LucideIcons.calendar, text: birthday),
                              if (placeOfBirth != null)
                                _InfoRow(icon: LucideIcons.mapPin, text: placeOfBirth),
                              const SizedBox(height: 24),
                              
                              // Seen Progress
                              if (totalReleased > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(l10n.personSeen.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(text: '$watchedPercent%', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                                          TextSpan(text: ' ($watchedCount/$totalReleased)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3)),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: watchedPercent / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 10),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],

                              ExternalLinks(
                                externalIds: details['external_ids'],
                                title: name,
                                homepage: details['homepage'],
                                type: 'person',
                                tmdbId: details['id'],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 64),

                    // Biography
                    if (biography != null && biography.isNotEmpty) ...[
                      Text(l10n.personBiography, style: DesktopTypography.sectionHeader),
                      const SizedBox(height: 16),
                      Text(
                        biography,
                        style: DesktopTypography.bodyPrimary,
                      ),
                      const SizedBox(height: 64),
                    ],

                    // Known For
                    if (topKnownFor.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(LucideIcons.film, color: AppTheme.accent, size: 24),
                          const SizedBox(width: 12),
                          Text(l10n.personKnownFor, style: DesktopTypography.sectionHeader),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 300,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topKnownFor.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final item = topKnownFor[index];
                            return SizedBox(
                              width: 160,
                              child: MediaCard(
                                title: item['title'] ?? item['name'] ?? 'Unknown',
                                posterPath: item['poster_path'],
                                releaseDate: item['release_date'] ?? item['first_air_date'],
                                rating: (item['vote_average'] as num?)?.toDouble(),
                                onTap: () => _navigateToMedia(context, item),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 64),
                    ],

                    // Filmography
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.layoutGrid, color: AppTheme.accent, size: 24),
                            const SizedBox(width: 12),
                            Text(l10n.personFilmography, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: onToggleHidden,
                          icon: Icon(showHidden ? LucideIcons.eyeOff : LucideIcons.eye, size: 16),
                          label: Text(showHidden ? l10n.personShowLess : l10n.personShowHidden),
                          style: TextButton.styleFrom(
                            foregroundColor: showHidden ? AppTheme.accent : AppTheme.textMuted,
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            enabledMouseCursor: SystemMouseCursors.click,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _FilmographyList(
                      credits: filmography.take(visibleCredits).toList(),
                      onMediaTap: (item) => _navigateToMedia(context, item),
                    ),

                    if (filmography.length > visibleCredits) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              l10n.personShowingCredits(visibleCredits, filmography.length),
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: onShowMore,
                              icon: const Icon(LucideIcons.plus, size: 18),
                              label: Text(l10n.personShowMore.toUpperCase()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.textWhite.withOpacity(0.05),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                                enabledMouseCursor: SystemMouseCursors.click,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Top Navbar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppNavbar(
            currentIndex: ref.watch(navIndexProvider),
            onTap: (index) {
              ref.read(navIndexProvider.notifier).state = index;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onSettingsTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            onLogoutTap: () {
              ref.read(authProvider.notifier).signOut();
            },
            onSearchTap: () => SearchOverlay.show(context),
          ),
        ),
      ],
    );
  }

  void _navigateToMedia(BuildContext context, Map<String, dynamic> item) {
    final type = item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaDetailsScreen(
          mediaId: item['id'].toString(),
          mediaType: type,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }
}

class _FilmographyList extends StatelessWidget {
  final List<dynamic> credits;
  final Function(Map<String, dynamic>) onMediaTap;

  const _FilmographyList({required this.credits, required this.onMediaTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: credits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = credits[index];
        final year = (item['release_date'] ?? item['first_air_date'] ?? '').toString().split('-').first;
        final title = item['title'] ?? item['name'] ?? 'Unknown';
        final posterPath = item['poster_path'];
        final isTv = item['media_type'] == 'tv';
        final role = item['character'] ?? item['job'] ?? '';
        final rating = (item['vote_average'] as num?)?.toDouble() ?? 0.0;

        return InkWell(
          onTap: () => onMediaTap(Map<String, dynamic>.from(item)),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                // Year
                SizedBox(
                  width: 50,
                  child: Text(
                    year.isEmpty ? '-' : year,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                // Poster Small
                Container(
                  width: 48,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    image: posterPath != null
                        ? DecorationImage(
                            image: NetworkImage('https://image.tmdb.org/t/p/w92$posterPath'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: posterPath == null ? const Icon(LucideIcons.film, size: 16, color: Colors.white10) : null,
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTv ? Colors.blue.withOpacity(0.1) : AppTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: (isTv ? Colors.blue : AppTheme.accent).withOpacity(0.2)),
                            ),
                            child: Text(
                              isTv ? l10n.personSeries.toUpperCase() : l10n.personMovie.toUpperCase(),
                              style: TextStyle(color: isTv ? Colors.blue : AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Rating
                if (rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.star, size: 10, color: Colors.amber, fill: 1.0),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
