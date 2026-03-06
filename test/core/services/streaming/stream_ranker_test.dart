import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/services/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';

void main() {
  group('StreamRanker scoring', () {
    test('Should prioritize Italian streams', () {
      final itaStream = StreamCandidate(
        title: 'Movie Title ITA ENG 1080p',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final engStream = StreamCandidate(
        title: 'Movie Title ENG 1080p',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      final itaScore = StreamRanker.score(itaStream);
      final engScore = StreamRanker.score(engStream);

      expect(itaScore > engScore, isTrue, reason: 'Italian should have higher score than English');
    });

    test('Should massively boost Multi (ITA+ENG)', () {
      final multiStream = StreamCandidate(
        title: 'Movie.Title.MULTI.ITA.ENG.1080p',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final itaOnlyStream = StreamCandidate(
        title: 'Movie.Title.ITA.1080p',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      final multiScore = StreamRanker.score(multiStream);
      final itaScore = StreamRanker.score(itaOnlyStream);

      expect(multiScore > itaScore, isTrue, reason: 'Multi should have higher score than single language');
    });

    test('Should prioritize 4K/2160p over 1080p', () {
      final k4Stream = StreamCandidate(
        title: 'Movie 4K HEVC',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final hdStream = StreamCandidate(
        title: 'Movie 1080p HEVC',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      expect(StreamRanker.score(k4Stream) > StreamRanker.score(hdStream), isTrue);
    });

    test('Should penalize Russian releases without Italian', () {
      final rusStream = StreamCandidate(
        title: 'Movie.RUSSIAN.lostfilm',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      
      expect(StreamRanker.score(rusStream) < 0, isTrue);
    });
  });

  group('StreamRanker parsing', () {
    test('Should parse resolution correctly', () {
      final meta = StreamRanker.parseMetadata('Movie 2160p HDR');
      expect(meta['resolution'], equals('4K'));
    });

    test('Should parse 10bit and HDR', () {
      final meta = StreamRanker.parseMetadata('Movie.1080p.10bit.HDR.HEVC');
      expect(meta['quality'], contains('10bit'));
      expect(meta['quality'], contains('HDR'));
    });

    test('Should detect languages', () {
      final meta = StreamRanker.parseMetadata('Movie ITA ENG');
      expect(meta['languages'], contains('ITA'));
      expect(meta['languages'], contains('ENG'));
    });

    test('Should parse file size', () {
      final meta = StreamRanker.parseMetadata('Movie [12.5 GB]');
      expect(meta['size'], equals('12.5 GB'));
    });
  });

  group('StreamRanker ranking', () {
    test('Should sort by cache status first, then score', () {
      final uncachedHigh = StreamCandidate(
        title: 'Movie ITA 4K Uncached',
        infoHash: 'h1',
        magnet: 'm1',
        seeds: 100,
        provider: 'P1',
        cachedOn: {}, // Not cached
      );
      final cachedLow = StreamCandidate(
        title: 'Movie ENG 720p Cached',
        infoHash: 'h2',
        magnet: 'm2',
        seeds: 1,
        provider: 'P1',
        cachedOn: {'P1': true}, // Cached
      );

      final result = StreamRanker.rank([uncachedHigh, cachedLow]);

      expect(result.first.infoHash, equals('h2'), reason: 'Cached stream should be first');
    });
  });
}
