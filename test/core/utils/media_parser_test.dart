import 'package:cinemuse_app/core/utils/media_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaParser', () {
    test('Parses SxxExx format', () {
      final result = MediaParser.parse('Fire Force S03E21 1080p');
      expect(result.season, 3);
      expect(result.episode, 21);
    });

    test('Parses X format', () {
      final result = MediaParser.parse('The.Office.1x05.HDTV.x264');
      expect(result.season, 1);
      expect(result.episode, 5);
    });

    test('Parses Absolute Episode (Anime style)', () {
      final result = MediaParser.parse('[HatSubs] One Piece - 955 (BD 1080p)');
      expect(result.absoluteEpisode, 955);
      expect(result.episode, 955); // Fallback if no season
    });

    test('Parses complicated anime title with both S/E and Abs', () {
      final result = MediaParser.parse(
        'Naruto Shippuden S10E05 - 201 [Bluray]',
      );
      expect(result.season, 10);
      expect(result.episode, 5);
      expect(result.absoluteEpisode, 201);
    });

    test('Match - Positive (Absolute Episode)', () {
      final matches = MediaParser.matches(
        '[Group] Naruto 300 [1080p].mkv',
        targetAbsoluteEpisode: 300,
      );
      expect(matches, isTrue);
    });

    test('Match - Positive (Season/Episode)', () {
      final matches = MediaParser.matches(
        'Fire.Force.S03E21.1080p.mkv',
        targetSeason: 3,
        targetEpisode: 21,
      );
      expect(matches, isTrue);
    });

    test('Match - Negative (Wrong Episode)', () {
      final matches = MediaParser.matches(
        'Fire.Force.S03E22.1080p.mkv',
        targetSeason: 3,
        targetEpisode: 21,
      );
      expect(matches, isFalse);
    });
  });

  group('MediaParser batches (REV-21)', () {
    test('a codec tag like x265-10bit is not an episode range', () {
      final result = MediaParser.parse('Show.S01E05.1080p.x265-10bit.mkv');
      expect(result.isBatch, isFalse);
    });

    test('a year range is not an episode range', () {
      final result = MediaParser.parse('Show.1999-2001.Documentary.mkv');
      expect(result.isBatch, isFalse);
    });

    test('a file without an episode number does not match every episode', () {
      final matches = MediaParser.matches(
        'Some.Show.Pilot.1080p.x265-10bit.mkv',
        targetSeason: 1,
        targetEpisode: 6,
      );
      expect(matches, isFalse);
    });

    test('a real episode range is still a batch and matches inside it', () {
      const name = '[Group] Show (01-26) [1080p]';
      expect(MediaParser.parse(name).isBatch, isTrue);
      expect(MediaParser.matches(name, targetAbsoluteEpisode: 13), isTrue);
      expect(MediaParser.matches(name, targetAbsoluteEpisode: 27), isFalse);
    });
  });

  group('MediaParser years (REV-21)', () {
    test('a year is not an absolute episode', () {
      final result = MediaParser.parse('Show.2019.S01E05.1080p.mkv');
      expect(result.absoluteEpisode, isNull);
      expect(result.season, 1);
      expect(result.episode, 5);
    });

    test('an episode number after the year is still found', () {
      final result = MediaParser.parse('[Group] Show (2019) - 07 [1080p]');
      expect(result.absoluteEpisode, 7);
    });
  });
}
