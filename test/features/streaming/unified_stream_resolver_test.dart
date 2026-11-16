import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/debrid/addon_link_check_service.dart';
import 'package:cinemuse_app/features/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/sources/stremio_source.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/streaming/debrid/composite_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/sources/base_source.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/streaming/anime/anime_mapping_service.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

class MockSource extends Mock implements BaseSource {}

class MockTmdbService extends Mock implements TmdbService {}

class MockAnimeMappingService extends Mock implements AnimeMappingService {}

class MockMediaRepository extends Mock implements MediaRepository {}

// Register fallback for StreamSearchContext if needed (for any())
class FakeStreamSearchContext extends Fake implements StreamSearchContext {}

/// TMDB's details answer [tmdb] as the app reads it.
MediaItem _details(String type, Map<String, dynamic> tmdb) =>
    MediaItem.fromTmdbDetails(tmdb, MediaItem.fromString(type));

void main() {
  late UnifiedStreamResolver resolver;
  late MockSource mockSource;
  late MockTmdbService mockTmdb;
  late MockAnimeMappingService mockAnime;
  late MockMediaRepository mockMedia;

  setUpAll(() {
    registerFallbackValue(FakeStreamSearchContext());
    registerFallbackValue(
      StreamCandidate(
        kind: StreamSourceKind.vod,
        title: '',
        infoHash: '',
        magnet: '',
        provider: '',
      ),
    );
    registerFallbackValue(
      MediaItem(
        tmdbId: 0,
        mediaType: MediaKind.movie,
        updatedAt: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockSource = MockSource();
    mockTmdb = MockTmdbService();
    mockAnime = MockAnimeMappingService();
    mockMedia = MockMediaRepository();

    when(() => mockSource.name).thenReturn('MockSource');
    when(
      () => mockSource.supportedCategories,
    ).thenReturn({'movie', 'tv', 'anime'});

    when(() => mockMedia.saveMediaItem(any())).thenAnswer((_) async => {});

    when(
      () => mockAnime.lookUp(
        tmdbId: any(named: 'tmdbId'),
        type: any(named: 'type'),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenAnswer((_) async => AnimeLookup.notAnime);

    resolver = UnifiedStreamResolver(
      sources: [mockSource],
      tmdbService: mockTmdb,
      animeMappingService: mockAnime,
      mediaRepository: mockMedia,
      settings: const UserSettings(),
      maxResolution: VideoResolution.r2160p,
    );
  });

  group('UnifiedStreamResolver.searchStreams', () {
    test('Should aggregate and deduplicate streams from sources', () async {
      // Setup TMDB mock
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {
          'id': 123,
          'imdb_id': 'tt123',
          'title': 'Test Movie',
        }),
      );
      when(
        () => mockTmdb.getImdbId(any(), any()),
      ).thenAnswer((_) async => 'tt123');

      // Setup Source mock with duplicate hashes
      final c1 = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Stream 1',
        infoHash: 'abc',
        magnet: 'm1',
        seeds: 10,
        provider: 'S1',
      );
      final c2 = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Stream 1 copy',
        infoHash: 'abc',
        magnet: 'm1',
        seeds: 5,
        provider: 'S1',
      );
      final c3 = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Stream 2',
        infoHash: 'def',
        magnet: 'm2',
        seeds: 2,
        provider: 'S1',
      );

      when(
        () => mockSource.search(any()),
      ).thenAnswer((_) async => [c1, c2, c3]);

      final results = await resolver.searchStreams('123', 'movie');

      expect(
        results.candidates.length,
        equals(2),
        reason: 'Should deduplicate by infoHash',
      );
      expect(results.candidates.any((c) => c.infoHash == 'abc'), isTrue);
    });

    // REV-331: a special no anime row covers searched as a non-anime show,
    // so the anime languages were not used.
    test(
      'an episode with no anime mapping of an anime show is anime',
      () async {
        when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
          (_) async => _details('movie', {
            'id': 1429,
            'imdb_id': 'tt2560140',
            'name': 'AoT',
          }),
        );
        when(
          () => mockAnime.lookUp(
            tmdbId: 1429,
            type: 'tv',
            season: 0,
            episode: 37,
          ),
        ).thenAnswer((_) async => const AnimeLookup(isAnime: true));
        when(
          () => mockSource.search(any()),
        ).thenAnswer((_) async => [_candidate('aot')]);

        final result = await resolver.searchStreams(
          '1429',
          'tv',
          season: 0,
          episode: 37,
        );

        final context =
            verify(() => mockSource.search(captureAny())).captured.single
                as StreamSearchContext;
        expect(context.isAnime, isTrue);
        expect(context.mapping, isNull);
        expect(result.isAnime, isTrue);
      },
    );

    test('Should handle source failures gracefully', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {'id': 123, 'imdb_id': 'tt123'}),
      );
      when(() => mockSource.search(any())).thenThrow(Exception('Source down'));

      expect(
        () => resolver.searchStreams('123', 'movie'),
        throwsA(isA<NoStreamsFailure>()),
      );
    });

    test('no add-ons enabled when the sources list is empty', () async {
      final emptyResolver = UnifiedStreamResolver(
        sources: [],
        tmdbService: mockTmdb,
        animeMappingService: mockAnime,
        mediaRepository: mockMedia,
        settings: const UserSettings(),
        maxResolution: VideoResolution.r2160p,
      );

      expect(
        () => emptyResolver.searchStreams('123', 'movie'),
        throwsA(
          isA<NoStreamsFailure>().having(
            (f) => f.reason,
            'reason',
            NoStreamsReason.noAddons,
          ),
        ),
      );
    });

    test('no title details when the details are null', () async {
      when(
        () => mockTmdb.getMediaDetails(any(), any()),
      ).thenAnswer((_) async => null);

      expect(
        () => resolver.searchStreams('123', 'movie'),
        throwsA(
          isA<NoStreamsFailure>().having(
            (f) => f.reason,
            'reason',
            NoStreamsReason.noDetails,
          ),
        ),
      );
    });

    group('a title TMDB knows no IMDb id for', () {
      final stream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Built-in stream',
        infoHash: '',
        magnet: '',
        url: 'https://example.com/film.mp4',
        provider: 'MockSource',
      );

      test('still gets the streams its sources find', () async {
        when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
          (_) async => _details('movie', {'id': 123, 'title': 'Small Film'}),
        );
        when(
          () => mockTmdb.getImdbId(any(), any()),
        ).thenAnswer((_) async => null);
        when(() => mockSource.search(any())).thenAnswer((_) async => [stream]);

        final result = await resolver.searchStreams('123', 'movie');

        expect(result.candidates.map((c) => c.title), ['Built-in stream']);
        final context =
            verify(() => mockSource.search(captureAny())).captured.single
                as StreamSearchContext;
        expect(context.imdbId, isNull);
        expect(context.tmdbId, '123');
      });

      test('an empty IMDb id counts as none', () async {
        when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
          (_) async => _details('movie', {
            'id': 123,
            'title': 'Small Film',
            'external_ids': {'imdb_id': ''},
          }),
        );
        when(
          () => mockTmdb.getImdbId(any(), any()),
        ).thenAnswer((_) async => '');
        when(() => mockSource.search(any())).thenAnswer((_) async => [stream]);

        await resolver.searchStreams('123', 'movie');

        final context =
            verify(() => mockSource.search(captureAny())).captured.single
                as StreamSearchContext;
        expect(context.imdbId, isNull);
      });
    });

    test(
      'Should report non-zero time elapsed in onStatusUpdate callbacks',
      () async {
        when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
          (_) async => _details('movie', {
            'id': 123,
            'imdb_id': 'tt123',
            'title': 'Test Movie',
          }),
        );

        // Simulate a search delay to let some elapsed time accumulate
        when(() => mockSource.search(any())).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 150));
          return [
            StreamCandidate(
              kind: StreamSourceKind.vod,
              title: 'Stream 1',
              infoHash: 'abc',
              magnet: 'm1',
              seeds: 10,
              provider: 'MockSource',
            ),
          ];
        });

        final updates = <List<ProviderSearchStatus>>[];

        await resolver.searchStreams(
          '123',
          'movie',
          onStatusUpdate: (statuses) {
            updates.add(List.from(statuses.map((s) => s.copyWith())));
          },
        );

        expect(
          updates.isNotEmpty,
          isTrue,
          reason: 'Should receive status updates',
        );

        // The final status update should show the provider finished
        final finalUpdate = updates.last;
        expect(finalUpdate.length, equals(1));
        expect(finalUpdate.first.status, equals(ProviderStatus.finished));
        expect(
          finalUpdate.first.timeElapsed.inMilliseconds,
          greaterThanOrEqualTo(100),
          reason: 'Finished status should record non-zero elapsed time',
        );
      },
    );

    test('no results when no streams are found', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {'id': 123, 'imdb_id': 'tt123'}),
      );
      when(() => mockSource.search(any())).thenAnswer((_) async => []);

      expect(
        () => resolver.searchStreams('123', 'movie'),
        throwsA(
          isA<NoStreamsFailure>().having(
            (f) => f.reason,
            'reason',
            NoStreamsReason.noResults,
          ),
        ),
      );
    });

    test(
      'Should timeout and mark provider as failed if enableAutoSkipProviders is true and search is slow',
      () {
        fakeAsync((async) {
          when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
            (_) async => _details('movie', {'id': 123, 'imdb_id': 'tt123'}),
          );

          // Simulate search taking 12 seconds
          when(() => mockSource.search(any())).thenAnswer((_) async {
            await Future.delayed(const Duration(seconds: 12));
            return [
              StreamCandidate(
                kind: StreamSourceKind.vod,
                title: 'Slow Stream',
                infoHash: 'abc',
                magnet: 'm1',
                seeds: 10,
                provider: 'MockSource',
              ),
            ];
          });

          final slowResolver = UnifiedStreamResolver(
            sources: [mockSource],
            tmdbService: mockTmdb,
            animeMappingService: mockAnime,
            mediaRepository: mockMedia,
            settings: const UserSettings(enableAutoSkipProviders: true),
            maxResolution: VideoResolution.r2160p,
          );

          final updates = <List<ProviderSearchStatus>>[];

          dynamic futureError;
          slowResolver
              .searchStreams(
                '123',
                'movie',
                onStatusUpdate: (statuses) {
                  updates.add(List.from(statuses.map((s) => s.copyWith())));
                },
              )
              .catchError((e) {
                futureError = e;
                return StreamSearchResult(candidates: []);
              });

          // Elapse 15 seconds to allow the search to time out at 10s
          async.elapse(const Duration(seconds: 15));

          // The future should have failed with "no results" because the only source timed out
          expect(
            futureError,
            isA<NoStreamsFailure>().having(
              (f) => f.reason,
              'reason',
              NoStreamsReason.noResults,
            ),
          );

          // Let's verify that the update logs showed a failed provider status with the timeout message
          expect(updates.isNotEmpty, isTrue);
          final finalUpdate = updates.last;
          expect(finalUpdate.length, equals(1));
          expect(finalUpdate.first.status, equals(ProviderStatus.failed));
          expect(finalUpdate.first.errorMessage, contains('Timeout after 10s'));
        });
      },
    );

    test(
      'Should NOT timeout if enableAutoSkipProviders is false and search is slow',
      () {
        fakeAsync((async) {
          when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
            (_) async => _details('movie', {
              'id': 123,
              'imdb_id': 'tt123',
              'title': 'Test Movie',
            }),
          );

          // Simulate search taking 35 seconds
          when(() => mockSource.search(any())).thenAnswer((_) async {
            await Future.delayed(const Duration(seconds: 35));
            return [
              StreamCandidate(
                kind: StreamSourceKind.vod,
                title: 'Slow Stream',
                infoHash: 'abc',
                magnet: 'm1',
                seeds: 10,
                provider: 'MockSource',
              ),
            ];
          });

          final slowResolver = UnifiedStreamResolver(
            sources: [mockSource],
            tmdbService: mockTmdb,
            animeMappingService: mockAnime,
            mediaRepository: mockMedia,
            settings: const UserSettings(enableAutoSkipProviders: false),
            maxResolution: VideoResolution.r2160p,
          );

          final updates = <List<ProviderSearchStatus>>[];

          dynamic result;
          slowResolver
              .searchStreams(
                '123',
                'movie',
                onStatusUpdate: (statuses) {
                  updates.add(List.from(statuses.map((s) => s.copyWith())));
                },
              )
              .then((res) {
                result = res;
              });

          // Elapse 40 seconds to allow the search to complete fully
          async.elapse(const Duration(seconds: 40));

          expect(result, isA<StreamSearchResult>());
          expect((result as StreamSearchResult).candidates.length, equals(1));

          expect(updates.isNotEmpty, isTrue);
          final finalUpdate = updates.last;
          expect(finalUpdate.length, equals(1));
          expect(finalUpdate.first.status, equals(ProviderStatus.finished));
          expect(finalUpdate.first.resultsCount, equals(1));
        });
      },
    );
  });

  group('UnifiedStreamResolver.resolveStream', () {
    test('Should return resolved stream directly if URL is present', () async {
      final candidate = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Test',
        infoHash: 'abc',
        magnet: 'mag',
        seeds: 1,
        provider: 'S',
        url: 'https://direct-link.com',
      );

      final result = await resolver.resolveStream(candidate);

      expect(result?.url, equals('https://direct-link.com'));
      expect(result?.provider, equals('S'));
    });

    test('passes the chosen fileId to the debrid service (REV-23)', () async {
      final debrid = _RecordingDebridService();
      final debridResolver = UnifiedStreamResolver(
        sources: [mockSource],
        tmdbService: mockTmdb,
        animeMappingService: mockAnime,
        mediaRepository: mockMedia,
        settings: const UserSettings(),
        maxResolution: VideoResolution.r2160p,
        debridService: CompositeDebridService([debrid]),
      );
      final candidate = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Season pack',
        infoHash: 'abc',
        magnet: 'magnet:?xt=urn:btih:abc',
        provider: 'Torrent Feed',
      );

      await debridResolver.resolveStream(
        candidate,
        season: 1,
        episode: 2,
        fileId: 3,
      );

      expect(debrid.lastFileId, 3);
      expect(debrid.lastSeason, 1);
      expect(debrid.lastEpisode, 2);
    });

    group('an add-on link that leads to its error video', () {
      late _MockLinkCheck linkCheck;
      late UnifiedStreamResolver checking;

      StreamCandidate linkFrom(String provider) => StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Episode',
        provider: provider,
        url: 'https://addon.example/resolve/abc',
      );

      setUp(() {
        linkCheck = _MockLinkCheck();
        when(
          () =>
              linkCheck.errorVideoReason(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => DebridRefusal.copyright);
        checking = UnifiedStreamResolver(
          sources: [
            mockSource,
            StremioSource(Dio(), '', name: 'Torrentio'),
          ],
          tmdbService: mockTmdb,
          animeMappingService: mockAnime,
          mediaRepository: mockMedia,
          settings: const UserSettings(),
          maxResolution: VideoResolution.r2160p,
          linkCheck: linkCheck,
        );
      });

      test('is not played: the failure says why', () async {
        await expectLater(
          checking.resolveStream(linkFrom('Torrentio')),
          throwsA(
            isA<DebridFileFailure>().having(
              (f) => f.reason,
              'reason',
              DebridRefusal.copyright,
            ),
          ),
        );
      });

      test('a built-in source\'s link is not checked', () async {
        final result = await checking.resolveStream(linkFrom('MockSource'));

        expect(result?.url, 'https://addon.example/resolve/abc');
        verifyNever(
          () =>
              linkCheck.errorVideoReason(any(), headers: any(named: 'headers')),
        );
      });
    });
  });

  group('UnifiedStreamResolver Cache Management', () {
    test('Should check and clear cache correctly', () async {
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {
          'id': 123,
          'imdb_id': 'tt123',
          'title': 'Test Movie',
        }),
      );
      when(() => mockSource.search(any())).thenAnswer(
        (_) async => [
          StreamCandidate(
            kind: StreamSourceKind.vod,
            title: 'Test Candidate',
            infoHash: 'hash1',
            magnet: 'mag1',
            seeds: 1,
            provider: 'MockSource',
          ),
        ],
      );

      // Initially cache is empty
      expect(resolver.hasCachedStream('123', 'movie'), isFalse);

      // Search to populate cache
      await resolver.searchStreams('123', 'movie');

      // Now cache should exist
      expect(resolver.hasCachedStream('123', 'movie'), isTrue);

      // Clear the specific cache entry
      resolver.clearCachedStream('123', 'movie');

      // Now cache should be gone
      expect(resolver.hasCachedStream('123', 'movie'), isFalse);
    });

    test('does not cache a search that was skipped early (STR-05)', () async {
      final slowSource = MockSource();
      final neverEnds = Completer<List<StreamCandidate>>();
      when(() => slowSource.name).thenReturn('Slow');
      when(() => slowSource.search(any())).thenAnswer((_) => neverEnds.future);
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {
          'id': 123,
          'imdb_id': 'tt123',
          'title': 'Test Movie',
        }),
      );
      when(
        () => mockSource.search(any()),
      ).thenAnswer((_) async => [_candidate('fast')]);
      final twoSources = UnifiedStreamResolver(
        sources: [mockSource, slowSource],
        tmdbService: mockTmdb,
        animeMappingService: mockAnime,
        mediaRepository: mockMedia,
        settings: const UserSettings(),
        maxResolution: VideoResolution.r2160p,
      );

      final result = await twoSources.searchStreams(
        '123',
        'movie',
        skipTrigger: Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(result.candidates, hasLength(1));
      expect(twoSources.hasCachedStream('123', 'movie'), isFalse);
    });

    test('does not cache a search where a provider failed (STR-05)', () async {
      final brokenSource = MockSource();
      when(() => brokenSource.name).thenReturn('Broken');
      when(
        () => brokenSource.search(any()),
      ).thenThrow(Exception('Source down'));
      when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
        (_) async => _details('movie', {
          'id': 123,
          'imdb_id': 'tt123',
          'title': 'Test Movie',
        }),
      );
      when(
        () => mockSource.search(any()),
      ).thenAnswer((_) async => [_candidate('ok')]);
      final twoSources = UnifiedStreamResolver(
        sources: [mockSource, brokenSource],
        tmdbService: mockTmdb,
        animeMappingService: mockAnime,
        mediaRepository: mockMedia,
        settings: const UserSettings(),
        maxResolution: VideoResolution.r2160p,
      );

      await twoSources.searchStreams('123', 'movie');

      expect(twoSources.hasCachedStream('123', 'movie'), isFalse);
    });

    test(
      'wraps errors on the cached path in a NoStreamsFailure (STR-06)',
      () async {
        final debrid = _MockCompositeDebridService();
        when(() => debrid.isEnabled).thenReturn(true);
        when(() => debrid.name).thenReturn('Debrid');
        var availabilityCalls = 0;
        when(() => debrid.checkDetailedAvailability(any())).thenAnswer((
          _,
        ) async {
          availabilityCalls++;
          if (availabilityCalls > 1) throw Exception('debrid down');
          return {};
        });
        when(() => mockTmdb.getMediaDetails(any(), any())).thenAnswer(
          (_) async => _details('movie', {
            'id': 123,
            'imdb_id': 'tt123',
            'title': 'Test Movie',
          }),
        );
        when(
          () => mockSource.search(any()),
        ).thenAnswer((_) async => [_candidate('hash1')]);
        final debridResolver = UnifiedStreamResolver(
          sources: [mockSource],
          tmdbService: mockTmdb,
          animeMappingService: mockAnime,
          mediaRepository: mockMedia,
          settings: const UserSettings(),
          maxResolution: VideoResolution.r2160p,
          debridService: debrid,
        );
        await debridResolver.searchStreams('123', 'movie');

        // Second search is served from the cache, then the check fails.
        await expectLater(
          debridResolver.searchStreams('123', 'movie'),
          throwsA(
            isA<NoStreamsFailure>().having(
              (f) => f.reason,
              'reason',
              NoStreamsReason.linkFailed,
            ),
          ),
        );
      },
    );
  });
}

StreamCandidate _candidate(String hash) => StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'Stream $hash',
  infoHash: hash,
  magnet: 'magnet:?xt=urn:btih:$hash',
  seeds: 1,
  provider: 'MockSource',
);

class _MockLinkCheck extends Mock implements AddonLinkCheckService {}

class _MockCompositeDebridService extends Mock
    implements CompositeDebridService {}

/// Fake debrid service that remembers what `resolve` was asked for.
class _RecordingDebridService implements BaseDebridService {
  int? lastFileId;
  int? lastSeason;
  int? lastEpisode;

  @override
  String get name => 'Fake';

  @override
  bool get isEnabled => true;

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async => {};

  @override
  Future<ResolvedStream?> resolve(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    lastFileId = fileId;
    lastSeason = season;
    lastEpisode = episode;
    return ResolvedStream(
      url: 'https://debrid.example/file',
      provider: name,
      candidate: candidate,
    );
  }
}
