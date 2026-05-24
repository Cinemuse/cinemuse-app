import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/media/data/tvtime_service.dart';

void main() {
  group('TvTimeService Integration Tests', () {
    late TvTimeService service;

    setUp(() {
      service = TvTimeService(Dio());
    });

    final results = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'tests': [],
    };

    tearDownAll(() {
      final proofFile = File('test/fixtures/scraper_proof_tvtime.json');
      if (!proofFile.existsSync()) {
        proofFile.createSync(recursive: true);
      }
      proofFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
      print('Proof written to: ${proofFile.path}');
    });

    test('Series Resolution (TVDB: 81189)', () async {
      final uuid = await service.resolveSeriesUuid(81189);
      expect(uuid, isNotNull);
      results['tests'].add({'name': 'Series Resolution', 'status': 'pass', 'uuid': uuid});
    });

    test('Series Comments', () async {
      final comments = await service.fetchSeriesComments(81189, limit: 3);
      expect(comments, isNotEmpty);
      results['tests'].add({'name': 'Series Comments', 'status': 'pass', 'count': comments.length, 'first_comment': comments.first.text});
    });

    test('Movie Resolution (IMDB: tt1375666)', () async {
      final uuid = await service.resolveMovieUuid('tt1375666');
      expect(uuid, isNotNull);
      results['tests'].add({'name': 'Movie Resolution', 'status': 'pass', 'uuid': uuid});
    });

    test('Movie Comments', () async {
      final comments = await service.fetchMovieComments('tt1375666', limit: 3);
      expect(comments, isNotEmpty);
      results['tests'].add({'name': 'Movie Comments', 'status': 'pass', 'count': comments.length, 'first_comment': comments.first.text});
    });

    test('Episode Resolution (Show: 81189, S01E01)', () async {
      final uuid = await service.resolveEpisodeUuid(81189, season: 1, episode: 1);
      expect(uuid, isNotNull);
      results['tests'].add({'name': 'Episode Resolution', 'status': 'pass', 'uuid': uuid});
    });

    test('Episode Comments', () async {
      final comments = await service.fetchEpisodeComments(81189, season: 1, episode: 1, limit: 3);
      expect(comments, isNotEmpty);
      results['tests'].add({'name': 'Episode Comments', 'status': 'pass', 'count': comments.length, 'first_comment': comments.first.text});
    });
  });
}
