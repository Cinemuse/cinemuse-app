import 'package:cinemuse_app/core/utils/episode_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpisodeParser', () {
    test('Parses SxxExx format', () {
      final result = EpisodeParser.parse('Fire Force S03E21 1080p');
      expect(result.season, 3);
      expect(result.episode, 21);
    });

    test('Parses X format', () {
      final result = EpisodeParser.parse('The.Office.1x05.HDTV.x264');
      expect(result.season, 1);
      expect(result.episode, 5);
    });

    test('Parses Absolute Episode (Anime style)', () {
      final result = EpisodeParser.parse(
        '[HatSubs] One Piece - 955 (BD 1080p)',
      );
      expect(result.absoluteEpisode, 955);
      expect(result.episode, 955); // Fallback if no season
    });

    test('Parses complicated anime title with both S/E and Abs', () {
      final result = EpisodeParser.parse(
        'Naruto Shippuden S10E05 - 201 [Bluray]',
      );
      expect(result.season, 10);
      expect(result.episode, 5);
      expect(result.absoluteEpisode, 201);
    });

    test('Match - Positive (Absolute Episode)', () {
      final matches = EpisodeParser.matches(
        '[Group] Naruto 300 [1080p].mkv',
        targetAbsoluteEpisode: 300,
      );
      expect(matches, isTrue);
    });

    test('Match - Positive (Season/Episode)', () {
      final matches = EpisodeParser.matches(
        'Fire.Force.S03E21.1080p.mkv',
        targetSeason: 3,
        targetEpisode: 21,
      );
      expect(matches, isTrue);
    });

    test('Match - Negative (Wrong Episode)', () {
      final matches = EpisodeParser.matches(
        'Fire.Force.S03E22.1080p.mkv',
        targetSeason: 3,
        targetEpisode: 21,
      );
      expect(matches, isFalse);
    });
  });

  group('EpisodeParser batches (REV-21)', () {
    test('a codec tag like x265-10bit is not an episode range', () {
      final result = EpisodeParser.parse('Show.S01E05.1080p.x265-10bit.mkv');
      expect(result.isBatch, isFalse);
    });

    test('a year range is not an episode range', () {
      final result = EpisodeParser.parse('Show.1999-2001.Documentary.mkv');
      expect(result.isBatch, isFalse);
    });

    test('a file without an episode number does not match every episode', () {
      final matches = EpisodeParser.matches(
        'Some.Show.Pilot.1080p.x265-10bit.mkv',
        targetSeason: 1,
        targetEpisode: 6,
      );
      expect(matches, isFalse);
    });

    test('a real episode range is still a batch and matches inside it', () {
      const name = '[Group] Show (01-26) [1080p]';
      expect(EpisodeParser.parse(name).isBatch, isTrue);
      expect(EpisodeParser.matches(name, targetAbsoluteEpisode: 13), isTrue);
      expect(EpisodeParser.matches(name, targetAbsoluteEpisode: 27), isFalse);
    });
  });

  group('EpisodeParser reads the episode', () {
    test('every way a name writes it', () {
      void expectEpisode(String name, {int? season, required int episode}) {
        final result = EpisodeParser.parse(name);
        expect(result.episode, episode, reason: name);
        expect(result.season, season, reason: name);
      }

      expectEpisode('Show.S01.E05.1080p.mkv', season: 1, episode: 5);
      expectEpisode('Show_S01E05_1080p.mkv', season: 1, episode: 5);
      expectEpisode('Show S01x03 Title.mkv', season: 1, episode: 3);
      expectEpisode('Show.S01E1000.mkv', season: 1, episode: 1000);
      expectEpisode('Show E05 1080p.mkv', episode: 5);
      expectEpisode('Show Ep05 1080p.mkv', episode: 5);
      expectEpisode('Show Ep.5.mkv', episode: 5);
      expectEpisode('Show - 5.mkv', episode: 5);
      expectEpisode('Show - 5 [1080p].mkv', episode: 5);
      expectEpisode('Show Episodio 5.mkv', episode: 5);
      expectEpisode('Show Season 2 Episode 5.mkv', season: 2, episode: 5);
      expectEpisode('Show 2 - 05.mkv', episode: 5);
    });

    test('numbers that are not an episode', () {
      for (final name in [
        'Show.1920x1080.mkv',
        'Show.H.264.mkv',
        'Show.H 265.mkv',
        'Show 12.5 GB.mkv',
        'Show 10-bit.mkv',
        'Show 60 FPS.mkv',
      ]) {
        final result = EpisodeParser.parse(name);
        expect(result.season, isNull, reason: name);
        expect(result.episode, isNull, reason: name);
        expect(result.absoluteEpisode, isNull, reason: name);
      }
      expect(EpisodeParser.parse('Show - 5.1 AAC.mkv').episode, isNull);
    });
  });

  group('EpisodeParser season packs', () {
    bool isBatch(String name) => EpisodeParser.parse(name).isBatch;

    test('a season and its episode are not a range', () {
      expect(isBatch('Show 2 - 05.mkv'), isFalse);
      expect(isBatch('Show 2-05.mkv'), isFalse);
      expect(EpisodeParser.matches('Show 2 - 05', targetEpisode: 3), isFalse);
      expect(EpisodeParser.matches('Show 2 - 05', targetEpisode: 5), isTrue);
    });

    test('ranges that really are ranges', () {
      for (final name in ['Show 01 - 26', 'Show 1-211', 'Show 001-500']) {
        expect(isBatch(name), isTrue, reason: name);
      }
      expect(isBatch('Show 2023-05-10 Special'), isFalse);
    });

    test('a pack of one season is not accepted for another', () {
      const name = 'Show S02 Complete 1080p';
      expect(isBatch(name), isTrue);
      expect(
        EpisodeParser.matches(name, targetSeason: 1, targetEpisode: 3),
        isFalse,
      );
      expect(
        EpisodeParser.matches(name, targetSeason: 2, targetEpisode: 3),
        isTrue,
      );
    });

    test('a pack of several seasons accepts only those', () {
      for (final name in ['Show S01-S03 1080p', 'Show S01-03 1080p']) {
        expect(
          EpisodeParser.matches(name, targetSeason: 2, targetEpisode: 3),
          isTrue,
          reason: name,
        );
        expect(
          EpisodeParser.matches(name, targetSeason: 4, targetEpisode: 3),
          isFalse,
          reason: name,
        );
      }
    });

    test('pack only as a whole word', () {
      expect(isBatch('Show.S01E05.REPACK.1080p.mkv'), isFalse);
      expect(isBatch('Wolfpack.2020.1080p.mkv'), isFalse);
      expect(isBatch('Show.S01.Pack.1080p'), isTrue);
    });

    test('complete and collection in the name of one episode', () {
      expect(isBatch('The.Collection.S01E03.1080p.mkv'), isFalse);
      expect(isBatch('A.Complete.Story.1x05.mkv'), isFalse);
      expect(isBatch('[Group] The Complete Story - 05 [1080p]'), isFalse);
      expect(isBatch('Show Complete Series 1080p'), isTrue);
      expect(isBatch('Show Stagione 1 Completa'), isTrue);
    });

    test('a number in the title of a pack is not its episode', () {
      expect(
        EpisodeParser.matches('Mob Psycho 100 Complete', targetEpisode: 5),
        isTrue,
      );
    });

    test('S01E01-E03 covers episodes 1 to 3 of that season', () {
      for (final name in ['Show.S01E01-E03.mkv', 'Show.S01E01-03.mkv']) {
        bool has(int season, int episode) => EpisodeParser.matches(
          name,
          targetSeason: season,
          targetEpisode: episode,
        );

        expect(has(1, 1), isTrue, reason: name);
        expect(has(1, 2), isTrue, reason: name);
        expect(has(1, 3), isTrue, reason: name);
        expect(has(1, 4), isFalse, reason: name);
        expect(has(2, 2), isFalse, reason: name);
      }
      expect(isBatch('Show.S01E05-720p.mkv'), isFalse);
    });
  });

  group('EpisodeParser years (REV-21)', () {
    test('a year is not an absolute episode', () {
      final result = EpisodeParser.parse('Show.2019.S01E05.1080p.mkv');
      expect(result.absoluteEpisode, isNull);
      expect(result.season, 1);
      expect(result.episode, 5);
    });

    test('an episode number after the year is still found', () {
      final result = EpisodeParser.parse('[Group] Show (2019) - 07 [1080p]');
      expect(result.absoluteEpisode, 7);
    });
  });
}
