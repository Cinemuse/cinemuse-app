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
      final result = MediaParser.parse('Naruto Shippuden S10E05 - 201 [Bluray]');
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
}
