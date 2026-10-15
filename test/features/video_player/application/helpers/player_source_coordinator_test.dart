import 'dart:async';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:fake_async/fake_async.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_source_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/stream_fallback_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockResolver extends Mock implements UnifiedStreamResolver {}

class _MockYouTubeSourceHandler extends Mock implements YouTubeSourceHandler {}

class _MockVideoController extends Mock implements VideoController {}

final _sourceA = StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'A',
  infoHash: 'aaaa',
  provider: 'test',
);
final _sourceB = StreamCandidate(
  kind: StreamSourceKind.vod,
  title: 'B',
  infoHash: 'bbbb',
  provider: 'test',
);

/// A coordinator playing [_sourceA], with [_sourceB] as the other source,
/// in the app language of [l10n] (English by default).
class _Harness {
  final player = _MockPlayer();
  final stream = _MockPlayerStream();
  final resolver = _MockResolver();
  final errors = <Object?>[];
  late CinemaPlayerState state;
  late PlayerSourceCoordinator coordinator;
  late ProviderContainer container;

  _Harness([AppLocalizations? l10n]) {
    when(() => player.stream).thenReturn(stream);
    when(() => player.state).thenReturn(const PlayerState());
    when(
      () => stream.duration,
    ).thenAnswer((_) => Stream.value(const Duration(minutes: 90)));
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
    when(() => player.seek(any())).thenAnswer((_) async {});
    when(player.play).thenAnswer((_) async {});

    state = CinemaPlayerState(
      controller: _MockVideoController(),
      availableStreams: [_sourceA, _sourceB],
      currentStream: ResolvedStream(
        url: 'https://a',
        provider: 'test',
        candidate: _sourceA,
      ),
      title: 'Movie',
    );

    final provider = Provider(
      (ref) => PlayerSourceCoordinator(
        ref: ref,
        player: player,
        getResolvedParams: () => const PlayerParams('550', 'movie'),
        youtubeSourceHandler: _MockYouTubeSourceHandler(),
        resolver: resolver,
        fallbackManager: StreamFallbackManager(),
        getTrackManager: () => null,
        getLiveTvCoordinator: () => null,
        isMounted: () => true,
        getCurrentState: () => state,
        onStateChanged: (s) => state = s,
        onError: (e, _) => errors.add(e),
        saveProgress: () async {},
      ),
    );
    container = ProviderContainer(
      overrides: [
        localizationsProvider.overrideWithValue(l10n ?? AppLocalizationsEn()),
      ],
    );
    coordinator = container.read(provider);
  }

  void resolves(StreamCandidate candidate, ResolvedStream? result) => when(
    () => resolver.resolveStream(
      candidate,
      season: any(named: 'season'),
      episode: any(named: 'episode'),
      fileId: any(named: 'fileId'),
    ),
  ).thenAnswer((_) async => result);
}

void main() {
  setUpAll(() {
    registerFallbackValue(Media('https://fallback'));
    registerFallbackValue(Duration.zero);
    registerFallbackValue(_sourceA);
  });

  group('performSoftRetry', () {
    test('a failed retry tries the next source (REV-144)', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.resolves(_sourceA, null);
      h.resolves(
        _sourceB,
        ResolvedStream(url: 'https://b', provider: 'test', candidate: _sourceB),
      );

      await h.coordinator.performSoftRetry();
      await pumpEventQueue();

      expect(h.errors, isEmpty);
      expect(h.state.currentStream?.candidate, _sourceB);
      expect(h.state.isResolving, isFalse);
    });

    test('with no other source, a failed retry shows the error', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.state = h.state.copyWith(availableStreams: [_sourceA]);
      h.resolves(_sourceA, null);

      await h.coordinator.performSoftRetry();
      await pumpEventQueue();

      expect(h.errors, hasLength(1));
    });
  });

  group('handlePlayerError', () {
    test('a real error with "track" in it is not ignored (REV-149)', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.resolves(_sourceA, null);

      h.coordinator.handlePlayerError(
        'Failed to open https://cdn.example/soundtrack.mkv.',
      );
      await pumpEventQueue();

      verify(
        () => h.resolver.resolveStream(
          _sourceA,
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          fileId: any(named: 'fileId'),
        ),
      ).called(1);
    });

    test('a failed external subtitle is still ignored', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);

      h.coordinator.handlePlayerError(
        'Can not open external file https://subs.example/en.srt.',
      );
      h.coordinator.handlePlayerError('Track 2 already selected.');
      await pumpEventQueue();

      verifyNever(
        () => h.resolver.resolveStream(
          any(),
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          fileId: any(named: 'fileId'),
        ),
      );
      expect(h.errors, isEmpty);
    });
  });

  group('changeFile', () {
    test('opens the file with the stream headers (REV-150)', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.resolves(
        _sourceA,
        ResolvedStream(
          url: 'https://a/file3',
          provider: 'test',
          candidate: _sourceA,
          headers: const {'Referer': 'https://host/'},
        ),
      );

      await h.coordinator.changeFile(3);

      final media =
          verify(
                () => h.player.open(captureAny(), play: any(named: 'play')),
              ).captured.single
              as Media;
      expect(media.httpHeaders, {'Referer': 'https://host/'});
      expect(h.state.currentStream?.url, 'https://a/file3');
    });

    test('a failure shows translated text, not the exception', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      when(
        () => h.resolver.resolveStream(
          _sourceA,
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          fileId: any(named: 'fileId'),
        ),
      ).thenThrow(Exception('boom at https://secret'));

      await h.coordinator.changeFile(3);

      expect(h.state.error, isNotNull);
      expect(h.state.error, isNot(contains('boom')));
      expect(h.state.isResolving, isFalse);
    });

    for (final l10n in [AppLocalizationsEn(), AppLocalizationsIt()]) {
      test(
        'offline: a short "no connection" text (${l10n.localeName})',
        () async {
          final h = _Harness(l10n);
          addTearDown(h.container.dispose);
          when(
            () => h.resolver.resolveStream(
              _sourceA,
              season: any(named: 'season'),
              episode: any(named: 'episode'),
              fileId: any(named: 'fileId'),
            ),
          ).thenThrow(const NetworkFailure('offline'));

          await h.coordinator.changeFile(3);

          expect(h.state.error, l10n.failureNetwork);
        },
      );
    }
  });

  test('a source that never loads ends with an error (REV-148)', () {
    fakeAsync((async) {
      final h = _Harness();
      addTearDown(h.container.dispose);
      // A stream that never sends a duration: the source never loads.
      when(
        () => h.stream.duration,
      ).thenAnswer((_) => StreamController<Duration>().stream);
      h.resolves(
        _sourceB,
        ResolvedStream(url: 'https://b', provider: 'test', candidate: _sourceB),
      );

      unawaited(h.coordinator.changeSource(_sourceB));
      async.elapse(const Duration(seconds: 29));
      expect(h.state.isResolving, isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(h.state.isResolving, isFalse);
      expect(h.state.error, isNotNull);
    });
  });
}
