import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/vod_source_handler.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockResolver extends Mock implements UnifiedStreamResolver {}

class _MockTmdbService extends Mock implements TmdbService {}

final _candidate = StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'A',
  infoHash: 'aaaa',
  provider: 'test',
);

void main() {
  setUpAll(() {
    registerFallbackValue(Media('https://fallback'));
    registerFallbackValue(_candidate);
  });

  late _MockPlayer player;
  late _MockResolver resolver;
  late Completer<StreamSearchResult> search;
  late VodSourceHandler handler;
  var isOpen = true;

  setUp(() {
    isOpen = true;
    player = _MockPlayer();
    resolver = _MockResolver();
    search = Completer();
    final tmdb = _MockTmdbService();
    when(
      () => tmdb.getMediaDetails(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => resolver.searchStreams(
        any(),
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        onStatusUpdate: any(named: 'onStatusUpdate'),
        skipTrigger: any(named: 'skipTrigger'),
        preloadedDetails: any(named: 'preloadedDetails'),
      ),
    ).thenAnswer((_) => search.future);
    when(
      () => resolver.resolveStream(
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenAnswer(
      (_) async => ResolvedStream(
        url: 'https://a',
        provider: 'test',
        candidate: _candidate,
      ),
    );
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});

    handler = VodSourceHandler(resolver, tmdb, player, isMounted: () => isOpen);
  });

  Future<VodInitializationResult?> start() => handler.initialize(
    const PlayerParams('550', 'movie'),
    onStatusUpdate: (_) {},
    onMediaDetailsFetched: (_) {},
  );

  test(
    'closing during the search resolves and opens nothing (REV-147)',
    () async {
      final result = start();
      await pumpEventQueue();

      isOpen = false;
      search.complete(StreamSearchResult(candidates: [_candidate]));

      expect(await result, isNull);
      verifyNever(
        () => resolver.resolveStream(
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
        ),
      );
      verifyNever(() => player.open(any(), play: any(named: 'play')));
    },
  );

  test('an open player resolves and plays the first source', () async {
    final result = start();
    search.complete(StreamSearchResult(candidates: [_candidate]));

    expect((await result)?.resolvedStream.url, 'https://a');
    verify(() => player.open(any(), play: true)).called(1);
  });

  test('a resumed episode opens at its saved spot, not at 0:00', () async {
    final result = handler.initialize(
      const PlayerParams(
        '129888',
        'tv',
        season: 1,
        episode: 9,
        startPosition: 2161,
      ),
      onStatusUpdate: (_) {},
      onMediaDetailsFetched: (_) {},
    );
    search.complete(StreamSearchResult(candidates: [_candidate]));
    await result;

    final opened =
        verify(() => player.open(captureAny(), play: true)).captured.single
            as Media;
    expect(opened.start, const Duration(seconds: 2161));
  });

  test('a title not started yet opens at the beginning', () async {
    final result = start();
    search.complete(StreamSearchResult(candidates: [_candidate]));
    await result;

    final opened =
        verify(() => player.open(captureAny(), play: true)).captured.single
            as Media;
    expect(opened.start, isNull);
  });

  // The screen tells these two apart from other errors (REV-164).
  test('no candidates throws a "no results" failure', () async {
    final result = start();
    search.complete(StreamSearchResult(candidates: []));

    await expectLater(
      result,
      throwsA(
        isA<NoStreamsFailure>().having(
          (f) => f.reason,
          'reason',
          NoStreamsReason.noResults,
        ),
      ),
    );
  });

  test('every source failing throws a StreamingFailure', () async {
    when(
      () => resolver.resolveStream(
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenAnswer((_) async => null);
    final result = start();
    search.complete(StreamSearchResult(candidates: [_candidate]));

    await expectLater(result, throwsA(isA<StreamingFailure>()));
  });

  // Every source sent an add-on error video: the screen says why, and
  // "still downloading" wins, since trying later can fix it.
  test('every source an error video: says the downloading one', () async {
    final refused = StreamCandidate(
      kind: StreamSourceKind.vod,
      title: 'Refused',
      infoHash: 'bbbb',
      provider: 'test',
    );
    final reasons = {
      refused.uniqueId: DebridRefusal.copyright,
      _candidate.uniqueId: DebridRefusal.downloading,
    };
    when(
      () => resolver.resolveStream(
        any(),
        season: any(named: 'season'),
        episode: any(named: 'episode'),
      ),
    ).thenAnswer((call) async {
      final candidate = call.positionalArguments.first as StreamCandidate;
      throw DebridFileFailure(reasons[candidate.uniqueId]!, 'error video');
    });
    final result = start();
    search.complete(StreamSearchResult(candidates: [refused, _candidate]));

    await expectLater(
      result,
      throwsA(
        isA<DebridFileFailure>().having(
          (f) => f.reason,
          'reason',
          DebridRefusal.downloading,
        ),
      ),
    );
    verifyNever(() => player.open(any(), play: any(named: 'play')));
  });
}
