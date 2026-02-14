import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/presentation/components/cast_list.dart';
import 'package:cinemuse_app/features/media/presentation/components/details_hero.dart';
import 'package:cinemuse_app/features/media/presentation/components/episode_list.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class MediaDetailsScreen extends ConsumerStatefulWidget {
  final String mediaId;
  final String mediaType;

  const MediaDetailsScreen({
    super.key,
    required this.mediaId,
    required this.mediaType,
  });

  @override
  ConsumerState<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends ConsumerState<MediaDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(mediaDetailsProvider((id: widget.mediaId, type: widget.mediaType)));

    return Scaffold(
      backgroundColor: AppTheme.primary, // Dark theme base
      body: detailsAsync.when(
        data: (details) {
          if (details == null) {
            return const Center(child: Text('Media not found'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 500, // Adjust for hero height
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: DetailsHero(details: details, type: widget.mediaType),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textWhite),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  // Cast Section
                  if (details['credits'] != null && details['credits']['cast'] != null)
                    CastList(cast: details['credits']['cast']),
                  
                  const SizedBox(height: 24),

                  // Season/Episodes Section (for Series)
                  if (widget.mediaType == 'tv' || widget.mediaType == 'series')
                    _SeasonSection(tmdbId: details['id'], seasons: details['seasons']),

                  // Reviews / Videos could go here
                  const SizedBox(height: 100),
                ]),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(AppLocalizations.of(context)!.detailsErrorLoading(err.toString()), style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ),
    );
  }
}

class _SeasonSection extends ConsumerWidget {
  final int tmdbId;
  final List<dynamic>? seasons;

  const _SeasonSection({required this.tmdbId, required this.seasons});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seasons == null || seasons!.isEmpty) return const SizedBox.shrink();

    final selectedSeason = ref.watch(selectedSeasonProvider);
    final validSeasons = seasons!.where((s) => s['season_number'] > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                AppLocalizations.of(context)!.detailsEpisodes,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Simple Season Selector
              DropdownButton<int>(
                value: selectedSeason,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textWhite),
                underline: Container(),
                items: validSeasons.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem<int>(
                    value: s['season_number'],
                    child: Text(s['name'] ?? AppLocalizations.of(context)!.seasonLabel(s['season_number'])),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(selectedSeasonProvider.notifier).state = val;
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        EpisodeList(tmdbId: tmdbId, seasonNumber: selectedSeason),
      ],
    );
  }
}
