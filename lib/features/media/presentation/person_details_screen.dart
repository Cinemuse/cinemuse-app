import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/person_domain_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_filmography_list.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_back_button.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

final personDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, id) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getPersonDetails(id);
});

class PersonDetailsScreen extends ConsumerStatefulWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailsScreen> createState() =>
      _PersonDetailsScreenState();
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

    final bodyContent = detailsAsync.when(
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (err, _) =>
          Center(child: Text(l10n.detailsErrorLoading(err.toString()))),
    );

    return Scaffold(backgroundColor: AppTheme.primary, body: bodyContent);
  }
}

class _PersonDetailsContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String name = (details['name'] ?? 'Unknown').toString();
    final String? profilePath = details['profile_path'] as String?;
    final String? biography = details['biography'] as String?;
    final String? birthday = details['birthday'] as String?;
    final String? placeOfBirth = details['place_of_birth'] as String?;

    final cast = details['combined_credits']?['cast'] as List<dynamic>? ?? [];
    final crew = details['combined_credits']?['crew'] as List<dynamic>? ?? [];

    final seenStats = PersonDomainService.calculateSeenStats(
      cast: cast,
      crew: crew,
      watchHistory: watchHistory,
    );
    final topKnownFor = PersonDomainService.extractTopKnownFor(cast);
    final filmography = PersonDomainService.processFilmography(
      cast: cast,
      crew: crew,
      showHidden: showHidden,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: responsivePadding,
            vertical: 32,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButton(onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 32),
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
                          borderRadius: AppTheme.radiusLg,
                          child: profilePath != null
                              ? CachedNetworkImage(
                                  imageUrl: TmdbImageHelper.profileUrl(
                                    context,
                                    profilePath,
                                  )!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
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
                          Text(
                            name,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textWhite,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 16),
                          if (birthday != null)
                            _InfoRow(
                              icon: LucideIcons.calendar,
                              text: birthday,
                            ),
                          if (placeOfBirth != null)
                            _InfoRow(
                              icon: LucideIcons.mapPin,
                              text: placeOfBirth,
                            ),
                          const SizedBox(height: 24),

                          // Seen Progress
                          if (seenStats.totalReleased > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.personSeen.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${seenStats.watchedPercent}%',
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' (${seenStats.watchedCount}/${seenStats.totalReleased})',
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.textWhite.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: seenStats.watchedPercent / 100,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accent.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                      ),
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
                  Text(
                    l10n.personBiography,
                    style: DesktopTypography.sectionHeader,
                  ),
                  const SizedBox(height: 16),
                  Text(biography, style: DesktopTypography.bodyPrimary),
                  const SizedBox(height: 64),
                ],

                // Known For
                if (topKnownFor.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.film,
                        color: AppTheme.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.personKnownFor,
                        style: DesktopTypography.sectionHeader,
                      ),
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
                            title: (item['title'] ?? item['name'] ?? 'Unknown')
                                .toString(),
                            posterPath: item['poster_path'] as String?,
                            releaseDate:
                                (item['release_date'] ?? item['first_air_date'])
                                    ?.toString(),
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
                        const Icon(
                          LucideIcons.layoutGrid,
                          color: AppTheme.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.personFilmography,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: onToggleHidden,
                      icon: Icon(
                        showHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 16,
                      ),
                      label: Text(
                        showHidden
                            ? l10n.personShowLess
                            : l10n.personShowHidden,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: showHidden
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PersonFilmographyList(
                  credits: filmography.take(visibleCredits).toList(),
                  onMediaTap: (item) => _navigateToMedia(context, item),
                ),

                if (filmography.length > visibleCredits) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          l10n.personShowingCredits(
                            filmography.length,
                            visibleCredits,
                          ),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onShowMore,
                            child: HoverScale(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.textWhite.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: AppTheme.radius12,
                                  border: Border.all(
                                    color: AppTheme.textWhite.withValues(
                                      alpha: 0.05,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.plus,
                                      color: AppTheme.textWhite,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      l10n.personShowMore.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
    );
  }

  void _navigateToMedia(BuildContext context, Map<String, dynamic> item) {
    final type =
        item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaDetailsScreen(
          mediaId: item['id'].toString(),
          mediaType: type.toString(),
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
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
