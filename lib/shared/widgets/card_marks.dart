import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// What a poster shows of the user's own relation to its title. The feature
/// screens fill it in, so `shared/` never reads the user's data itself.
class CardMarks extends Equatable {
  /// A film seen, or a series finished or up to date.
  final bool isWatched;

  /// The user's own score, 1 to 10; null when not rated.
  final int? ownScore;

  final bool isWatchlisted;
  final bool isFavorite;

  const CardMarks({
    this.isWatched = false,
    this.ownScore,
    this.isWatchlisted = false,
    this.isFavorite = false,
  });

  static const none = CardMarks();

  bool get hasPosterMark => isWatched || ownScore != null;

  bool get hasListMark => isWatchlisted || isFavorite;

  CardMarks copyWith({
    bool? isWatched,
    bool? isWatchlisted,
    bool? isFavorite,
    bool clearScore = false,
  }) => CardMarks(
    isWatched: isWatched ?? this.isWatched,
    ownScore: clearScore ? null : ownScore,
    isWatchlisted: isWatchlisted ?? this.isWatchlisted,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  @override
  List<Object?> get props => [isWatched, ownScore, isWatchlisted, isFavorite];
}

/// The app's one "watched" tick: white in a green circle, on episodes and
/// posters alike.
class WatchedTick extends StatelessWidget {
  /// The tick's own size; the circle adds a third of it around.
  final double size;

  const WatchedTick({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size / 3),
      decoration: const BoxDecoration(
        color: AppTheme.success,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, color: AppTheme.textWhite, size: size),
    );
  }
}

/// The poster's top-left corner: the watched tick, then the
/// user's score beside a full wreath (too small to count leaves). The tick
/// comes first, so it is always in the same spot.
class CardMarksBadge extends StatelessWidget {
  final CardMarks marks;

  const CardMarksBadge({super.key, required this.marks});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final score = marks.ownScore;
    return Semantics(
      label: [
        if (marks.isWatched) l10n.detailsWatched,
        if (score != null) l10n.ownReviewScoreLabel(score),
      ].join(', '),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alone, as on the episodes: it needs no patch to be seen.
            if (marks.isWatched) const WatchedTick(),
            if (marks.isWatched && score != null) const SizedBox(width: 4),
            if (score != null)
              // The wreath and number need the dark patch on a bright poster.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Wreath(score: 10, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bookmark and the heart under the poster, opposite its public score.
class CardListIcons extends StatelessWidget {
  final CardMarks marks;

  const CardListIcons({super.key, required this.marks});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marks.isWatchlisted)
          Icon(
            Icons.bookmark,
            size: 13,
            color: AppTheme.watchlist,
            semanticLabel: l10n.cardInWatchlist,
          ),
        if (marks.isWatchlisted && marks.isFavorite) const SizedBox(width: 4),
        if (marks.isFavorite)
          Icon(
            Icons.favorite,
            size: 13,
            color: AppTheme.favorites,
            semanticLabel: l10n.cardInFavorites,
          ),
      ],
    );
  }
}
