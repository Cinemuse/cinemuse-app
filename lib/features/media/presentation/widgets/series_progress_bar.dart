import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SeriesProgressBar extends ConsumerWidget {
  final Map<String, dynamic> details;

  const SeriesProgressBar({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tmdbId = details['id'] as int;

    final watchedEpisodesMap = ref.watch(watchedEpisodesMapProvider(tmdbId));
    final progress = ref.watch(seriesDomainServiceProvider).calculateSeriesProgress(
          details: details,
          watchedEpisodesMap: watchedEpisodesMap,
        );

    if (progress == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.detailsSeriesProgress.toUpperCase(),
                style: AppTheme.monoStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${progress.percentage}% (${progress.watchedCount}/${progress.totalCount})',
                style: AppTheme.monoStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: AppTheme.textWhite.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
