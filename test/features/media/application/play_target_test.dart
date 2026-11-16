import 'package:cinemuse_app/features/media/application/play_target.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_test/flutter_test.dart';

WatchHistory _history({
  required MediaKind type,
  required WatchStatus status,
  int progress = 0,
  int? season,
  int? episode,
}) => WatchHistory(
  userId: 'u1',
  tmdbId: 1429,
  mediaType: type,
  status: status,
  progressSeconds: progress,
  lastWatchedAt: DateTime.utc(2026, 10, 13),
  season: season,
  episode: episode,
);

void main() {
  group('PlayTarget.fromHistory (REV-234)', () {
    test('a completed series starts over at S1E1, not the last episode', () {
      final target = PlayTarget.fromHistory(
        _history(
          type: MediaKind.tv,
          status: WatchStatus.completed,
          progress: 1200,
          season: 4,
          episode: 30,
        ),
        isTV: true,
      );

      expect(target.season, 1);
      expect(target.episode, 1);
      expect(target.startSeconds, 0);
      expect(target.isResume, isFalse);
    });

    test('a series in progress resumes its episode at the saved spot', () {
      final target = PlayTarget.fromHistory(
        _history(
          type: MediaKind.tv,
          status: WatchStatus.watching,
          progress: 300,
          season: 2,
          episode: 5,
        ),
        isTV: true,
      );

      expect((target.season, target.episode, target.startSeconds), (2, 5, 300));
      expect(target.isResume, isTrue);
    });

    test('a series never started plays S1E1', () {
      final target = PlayTarget.fromHistory(null, isTV: true);

      expect((target.season, target.episode, target.startSeconds), (1, 1, 0));
    });

    test('a dropped series still plays where it was left', () {
      final target = PlayTarget.fromHistory(
        _history(
          type: MediaKind.tv,
          status: WatchStatus.dropped,
          season: 3,
          episode: 2,
        ),
        isTV: true,
      );

      expect((target.season, target.episode, target.isResume), (3, 2, false));
    });

    test('a completed movie starts from the beginning', () {
      final target = PlayTarget.fromHistory(
        _history(
          type: MediaKind.movie,
          status: WatchStatus.completed,
          progress: 6000,
        ),
        isTV: false,
      );

      expect(target.season, isNull);
      expect(target.startSeconds, 0);
    });

    test('a movie stopped halfway resumes', () {
      final target = PlayTarget.fromHistory(
        _history(
          type: MediaKind.movie,
          status: WatchStatus.watching,
          progress: 2400,
        ),
        isTV: false,
      );

      expect(
        (target.season, target.startSeconds, target.isResume),
        (null, 2400, true),
      );
    });
  });
}
