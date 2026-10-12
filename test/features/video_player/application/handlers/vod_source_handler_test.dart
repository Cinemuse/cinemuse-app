import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/streaming/models/streaming_exceptions.dart';
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
    onMediaDetailsFetched: (_, _) {},
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

  // The screen tells these two apart from other errors (REV-164).
  test('no candidates throws NoResultsFoundException', () async {
    final result = start();
    search.complete(StreamSearchResult(candidates: []));

    await expectLater(result, throwsA(isA<NoResultsFoundException>()));
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
}
