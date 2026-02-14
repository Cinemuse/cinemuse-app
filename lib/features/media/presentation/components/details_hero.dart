import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/presentation/components/action_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class DetailsHero extends ConsumerWidget {
  final Map<String, dynamic> details;
  final String type; // 'movie' or 'tv'

  const DetailsHero({
    super.key,
    required this.details,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdropPath = details['backdrop_path'];
    final posterPath = details['poster_path'];
    final title = details['title'] ?? details['name'] ?? 'Unknown Title';
    final tagline = details['tagline'];
    final overview = details['overview'];
    final voteAverage = details['vote_average']?.toStringAsFixed(1);
    final runtime = type == 'movie' 
        ? details['runtime'] 
        : (details['episode_run_time'] as List?)?.firstOrNull;
    final genres = (details['genres'] as List?)?.map((g) => g['name']).join(', ');
    final year = (details['release_date'] ?? details['first_air_date'])?.toString().split('-').first ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop Image
        if (backdropPath != null)
          Image.network(
            'https://image.tmdb.org/t/p/original$backdropPath',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
          ),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withOpacity(0.3),
                AppTheme.primary.withOpacity(0.6),
                AppTheme.primary,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tagline
              if (tagline != null && tagline.isNotEmpty)
                Text(
                  '"$tagline"',
                  style: TextStyle(
                    color: AppTheme.textWhite.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 8),

              // Title
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: AppTheme.primary, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 8),

              // Metadata Row
              Row(
                children: [
                  if (year.isNotEmpty) _buildMetadataChip(year),
                  if (runtime != null) _buildMetadataChip('${runtime}m'),
                  if (voteAverage != null) 
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(voteAverage, style: const TextStyle(color: AppTheme.textWhite)),
                      ],
                    ),
                  // if (details['certification'] != null) _buildMetadataChip(details['certification']),
                ],
              ),
              const SizedBox(height: 8),

              // Genres
              if (genres != null)
                Text(
                  genres,
                  style: TextStyle(color: AppTheme.textWhite.withOpacity(0.8), fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  ActionButton(
                    icon: Icons.play_arrow,
                    label: AppLocalizations.of(context)!.detailsPlay,
                    onPressed: () {
                      // Navigate to player or resume
                    },
                    isPrimary: true,
                  ),
                  const SizedBox(width: 12),
                  ActionButton(
                    icon: Icons.add,
                    label: AppLocalizations.of(context)!.detailsMyList,
                    onPressed: () {
                      // Toggle Watchlist
                    },
                  ),
                   const SizedBox(width: 12),
                   // Track/Check Button could be a separate widget or specialized
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textWhite.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
