import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_view.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_card.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_card_rows.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The timeline view: a header per day, month or year, then its cards. A sliver.
class WatchHistoryTimeline extends ConsumerWidget {
  final List<TimelineSection> sections;
  final TimelineGranularity granularity;

  const WatchHistoryTimeline({
    super.key,
    required this.sections,
    required this.granularity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = ref.watch(settingsProvider.select((s) => s.appLanguage));

    return WatchHistoryCardRows(
      sections: [
        for (final section in sections)
          WatchHistoryCardSection(
            header: _SectionHeader(
              title: _sectionTitle(section, l10n, language),
              count: section.decks.length,
            ),
            cardCount: section.decks.length,
            cardBuilder: (index) {
              final deck = section.decks[index];
              return WatchHistoryCard(
                item: deck.item,
                stackCount: deck.stackCount,
                infoText: _episodeText(deck.episodeLabel, l10n),
              );
            },
          ),
      ],
    );
  }

  String _sectionTitle(
    TimelineSection section,
    AppLocalizations l10n,
    String language,
  ) => switch (section.recentDay) {
    TimelineRecentDay.today => l10n.watchHistoryDateToday,
    TimelineRecentDay.yesterday => l10n.watchHistoryDateYesterday,
    TimelineRecentDay.thisWeek => l10n.watchHistoryDateThisWeek,
    TimelineRecentDay.thisMonth => l10n.watchHistoryDateThisMonth,
    null => switch (granularity) {
      TimelineGranularity.daily => DateFormat.yMMMMd(language),
      TimelineGranularity.monthly => DateFormat.yMMMM(language),
      TimelineGranularity.yearly => DateFormat.y(language),
    }.format(section.date),
  };

  String? _episodeText(EpisodeLabel? label, AppLocalizations l10n) =>
      switch (label) {
        null => null,
        SingleEpisodeLabel(:final season, :final episode) =>
          l10n.seasonEpisodeShort(season, episode),
        EpisodeRangeLabel(:final season, :final first, :final last) =>
          l10n.watchHistoryEpisodeRange(season, first, last),
        TwoSeasonLabel() => l10n.watchHistoryMultiSeasonRange(
          label.firstSeason,
          label.firstEpisode,
          label.lastSeason,
          label.lastEpisode,
        ),
        SeasonRangeLabel(:final firstSeason, :final lastSeason) =>
          l10n.watchHistorySeasonRange(firstSeason, lastSeason),
      };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
            boxShadow: AppTheme.shadowNeonSm,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Text(
            l10n.watchHistorySubtitle(count),
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
