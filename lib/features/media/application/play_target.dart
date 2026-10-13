import 'package:cinemuse_app/features/media/domain/watch_history.dart';

/// What the details page's Play button plays. The button label and the
/// action both read it, so they can't disagree (REV-234).
class PlayTarget {
  /// Season and episode to play; `null` for a movie.
  final int? season;
  final int? episode;

  /// Where to start, in seconds (0 = from the beginning).
  final int startSeconds;

  const PlayTarget({this.season, this.episode, this.startSeconds = 0});

  bool get isResume => startSeconds > 0;

  /// A title in progress (watching or dropped) plays its saved episode at its
  /// saved spot. A finished or never-started title starts over: S1E1 for a
  /// series, the beginning for a movie.
  factory PlayTarget.fromHistory(WatchHistory? history, {required bool isTV}) {
    final inProgress = history != null && !history.isCompleted;
    if (!isTV) {
      return PlayTarget(startSeconds: inProgress ? history.progressSeconds : 0);
    }
    if (!inProgress) return const PlayTarget(season: 1, episode: 1);
    return PlayTarget(
      season: history.season ?? 1,
      episode: history.episode ?? 1,
      startSeconds: history.progressSeconds,
    );
  }
}
