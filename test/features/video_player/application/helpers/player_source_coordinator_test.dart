import 'dart:async';

import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:fake_async/fake_async.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_playback_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_source_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/stream_fallback_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/application/track_choices.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:cinemuse_app/l10n/app_localizations_it.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockResolver extends Mock implements UnifiedStreamResolver {}

class _MockYouTubeSourceHandler extends Mock implements YouTubeSourceHandler {}

class _MockVideoController extends Mock implements VideoController {}

class _MockLiveTv extends Mock implements LiveTvPlaybackCoordinator {}

class _MockTrackManager extends Mock implements TrackManager {}

class _ItalianSoundSettings extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings(playerLanguage: 'it');
}

/// A source whose name says it has sound in [languages].
StreamCandidate _sourceIn(String title, List<String> languages) =>
    StreamCandidate(
      kind: StreamSourceKind.vod,
      title: title,
      infoHash: title.toLowerCase(),
      provider: 'test',
      metadata: StreamMetadata(
        video: const VideoMetadata(),
        audio: const AudioMetadata(),
        languages: languages,
      ),
    );

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
/// in the app language of [l10n] (English by default); with [liveTv], a live
/// channel instead; [tracks] answers sound errors and the sound language.
/// Italian is the preferred sound.
class _Harness {
  final player = _MockPlayer();
  final stream = _MockPlayerStream();
  final resolver = _MockResolver();
  final errors = <Object?>[];
  final fallbackManager = StreamFallbackManager();
  final LiveTvPlaybackCoordinator? liveTv;
  final TrackManager? tracks;
  late CinemaPlayerState state;
  late PlayerSourceCoordinator coordinator;
  late ProviderContainer container;

  _Harness({AppLocalizations? l10n, this.liveTv, this.tracks}) {
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
        getResolvedParams: () => liveTv != null
            ? const PlayerParams('rai1', 'livetv')
            : const PlayerParams('550', 'movie'),
        youtubeSourceHandler: _MockYouTubeSourceHandler(),
        resolver: resolver,
        fallbackManager: fallbackManager,
        getTrackManager: () => tracks,
        getLiveTvCoordinator: () => liveTv,
        isMounted: () => true,
        getCurrentState: () => state,
        onStateChanged: (s) => state = s,
        onError: (e, _) => errors.add(e),
        saveProgress: () async {},
      ),
    );
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        localizationsProvider.overrideWithValue(l10n ?? AppLocalizationsEn()),
        settingsProvider.overrideWith(_ItalianSoundSettings.new),
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

  group('an episode resumed at 36:01', () {
    const saved = Duration(minutes: 36, seconds: 1);
    final linkB = ResolvedStream(
      url: 'https://b',
      provider: 'test',
      candidate: _sourceB,
    );

    test('a switch before the player got there starts at 36:01', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.fallbackManager.resumeAt(saved);
      h.resolves(_sourceB, linkB);

      // The player still says 0:00: the first source is still loading.
      await h.coordinator.changeSource(_sourceB, isManual: false);

      verify(() => h.player.seek(saved)).called(1);
    });

    test('a reconnect before the player got there opens at 36:01', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.fallbackManager.resumeAt(saved);
      h.resolves(
        _sourceA,
        ResolvedStream(url: 'https://a', provider: 'test', candidate: _sourceA),
      );

      await h.coordinator.performSoftRetry();

      final opened =
          verify(() => h.player.open(captureAny(), play: false)).captured.single
              as Media;
      expect(opened.start, saved);
      verify(() => h.player.seek(saved)).called(1);
    });

    test('once the player got there, a switch starts where it is', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.fallbackManager.resumeAt(saved);
      h.resolves(_sourceB, linkB);
      when(
        () => h.player.state,
      ).thenReturn(const PlayerState(position: Duration(minutes: 40)));

      await h.coordinator.changeSource(_sourceB, isManual: false);

      verify(() => h.player.seek(const Duration(minutes: 40))).called(1);
    });

    test('after the user moved the video, a switch starts there', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);
      h.fallbackManager.resumeAt(saved);
      h.fallbackManager.forgetResumePoint();
      h.resolves(_sourceB, linkB);
      when(
        () => h.player.state,
      ).thenReturn(const PlayerState(position: Duration(minutes: 2)));

      await h.coordinator.changeSource(_sourceB);

      verify(() => h.player.seek(const Duration(minutes: 2))).called(1);
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

    TrackManager soundError(AudioErrorRecovery? result) {
      final tracks = _MockTrackManager();
      when(() => tracks.recoverFromAudioError(any())).thenReturn(result);
      when(
        () => tracks.soundLanguage(any()),
      ).thenAnswer((_) async => SoundLanguage.unknown);
      return tracks;
    }

    void verifyNeverResolved(StreamCandidate candidate, _Harness h) =>
        verifyNever(
          () => h.resolver.resolveStream(
            candidate,
            season: any(named: 'season'),
            episode: any(named: 'episode'),
            fileId: any(named: 'fileId'),
          ),
        );

    test('a sound error with another track keeps the source', () async {
      final h = _Harness(tracks: soundError(AudioErrorRecovery.switchedTrack));
      addTearDown(h.container.dispose);

      h.coordinator.handlePlayerError(
        "Failed to initialize a decoder for codec 'truehd'.",
      );
      await pumpEventQueue();

      verifyNeverResolved(_sourceA, h);
      verifyNeverResolved(_sourceB, h);
      expect(h.state.currentStream?.candidate, _sourceA);
      expect(h.errors, isEmpty);
    });

    test('a sound error with no track left moves to the next source', () async {
      final h = _Harness(tracks: soundError(AudioErrorRecovery.noTrackLeft));
      addTearDown(h.container.dispose);
      h.resolves(
        _sourceB,
        ResolvedStream(url: 'https://b', provider: 'test', candidate: _sourceB),
      );

      h.coordinator.handlePlayerError(
        "Failed to initialize a decoder for codec 'truehd'.",
      );
      await pumpEventQueue();

      verifyNeverResolved(_sourceA, h); // no retry of the same file
      verify(
        () => h.resolver.resolveStream(
          _sourceB,
          season: any(named: 'season'),
          episode: any(named: 'episode'),
          fileId: any(named: 'fileId'),
        ),
      ).called(1);
      expect(h.errors, isEmpty);
    });

    _MockLiveTv liveTvPlaying() {
      final live = _MockLiveTv();
      when(() => live.isChangingChannel).thenReturn(false);
      when(
        () => live.handleFailover(
          any(),
          isConnectionError: any(named: 'isConnectionError'),
        ),
      ).thenAnswer((_) async {});
      return live;
    }

    test('live TV: a decoding error keeps the channel playing', () async {
      final live = liveTvPlaying();
      final h = _Harness(liveTv: live);
      addTearDown(h.container.dispose);

      h.coordinator.handlePlayerError('Error decoding audio.');
      h.coordinator.handlePlayerError('Error decoding video.');
      await pumpEventQueue();

      verifyNever(
        () => live.handleFailover(
          any(),
          isConnectionError: any(named: 'isConnectionError'),
        ),
      );
    });

    test('a decoder that fails to start keeps the film', () async {
      final h = _Harness();
      addTearDown(h.container.dispose);

      h.coordinator.handlePlayerError('Could not open codec.');
      await pumpEventQueue();

      verifyNeverResolved(_sourceA, h);
      verifyNeverResolved(_sourceB, h);
      expect(h.errors, isEmpty);
    });

    test('live TV: a decoder that fails to start keeps the channel', () async {
      final live = liveTvPlaying();
      final h = _Harness(liveTv: live);
      addTearDown(h.container.dispose);

      h.coordinator.handlePlayerError('Could not open codec.');
      await pumpEventQueue();

      verifyNever(
        () => live.handleFailover(
          any(),
          isConnectionError: any(named: 'isConnectionError'),
        ),
      );
    });

    void playingChannel(_Harness h, String url) => h.state = h.state.copyWith(
      currentStream: ResolvedStream(
        url: url,
        provider: 'test',
        candidate: _sourceA,
      ),
    );

    test('live TV: one picture size that fails to open keeps the channel', () {
      final live = liveTvPlaying();
      final h = _Harness(liveTv: live);
      addTearDown(h.container.dispose);
      playingChannel(h, 'https://live.example/ch/index.m3u8');

      h.coordinator.handlePlayerError(
        'Failed to open https://live.example/ch/video=1000000.m3u8.',
      );

      verifyNever(
        () => live.handleFailover(
          any(),
          isConnectionError: any(named: 'isConnectionError'),
        ),
      );
    });

    test('live TV: a stream that fails to open still switches link', () async {
      final live = liveTvPlaying();
      final h = _Harness(liveTv: live);
      addTearDown(h.container.dispose);
      playingChannel(h, 'https://live.example/1');

      h.coordinator.handlePlayerError('Failed to open https://live.example/1.');
      await pumpEventQueue();

      verify(
        () => live.handleFailover(
          'Failed to open https://live.example/1.',
          isConnectionError: true,
        ),
      ).called(1);
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
          final h = _Harness(l10n: l10n);
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

  test(
    'a picked source with no link says so, not "something went wrong"',
    () async {
      final l10n = AppLocalizationsIt();
      final h = _Harness(l10n: l10n);
      addTearDown(h.container.dispose);
      h.resolves(_sourceB, null);

      await h.coordinator.changeSource(_sourceB);

      expect(h.state.error, l10n.streamingErrorResolutionFailed);
    },
  );

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

  group('a source without the preferred sound language', () {
    final subtitlesOnly = _sourceIn('Subtitles only', ['ITA']);
    final englishOnly = _sourceIn('English only', ['ENG']);
    final dubbed = _sourceIn('Dubbed', ['ITA']);
    final l10n = AppLocalizationsEn();
    final italian = l10n.languageName('it');

    /// A harness playing [subtitlesOnly] among [sources], whose files answer
    /// [sounds] one after the other.
    _Harness playing(
      List<StreamCandidate> sources,
      List<SoundLanguage> sounds,
    ) {
      final tracks = _MockTrackManager();
      final answers = [...sounds];
      when(
        () => tracks.soundLanguage(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
      when(
        () => tracks.ensurePreferredTrack(isAnime: any(named: 'isAnime')),
      ).thenAnswer((_) async {});
      final h = _Harness(tracks: tracks);
      h.state = h.state.copyWith(
        availableStreams: sources,
        currentStream: ResolvedStream(
          url: 'https://subs',
          provider: 'test',
          candidate: subtitlesOnly,
        ),
      );
      for (final source in sources) {
        h.resolves(
          source,
          ResolvedStream(
            url: 'https://${source.infoHash}',
            provider: 'test',
            candidate: source,
          ),
        );
      }
      return h;
    }

    void verifyNeverResolved(_Harness h, StreamCandidate source) => verifyNever(
      () => h.resolver.resolveStream(
        source,
        season: any(named: 'season'),
        episode: any(named: 'episode'),
        fileId: any(named: 'fileId'),
      ),
    );

    test('moves on to the next source whose name says it has it', () async {
      final h = playing(
        [subtitlesOnly, englishOnly, dubbed],
        [SoundLanguage.missing, SoundLanguage.present],
      );
      addTearDown(h.container.dispose);

      await h.coordinator.skipIfSoundLanguageMissing(isManual: false);
      await pumpEventQueue();

      expect(h.state.currentStream?.candidate, dubbed);
      verifyNeverResolved(h, englishOnly);
      expect(
        h.state.notification,
        l10n.playerSoundLanguageMissingTryingNext(italian),
      );
      expect(h.errors, isEmpty);
    });

    test('stays when no other source says it has it, and says so', () async {
      final h = playing([subtitlesOnly, englishOnly], [SoundLanguage.missing]);
      addTearDown(h.container.dispose);

      await h.coordinator.skipIfSoundLanguageMissing(isManual: false);
      await pumpEventQueue();

      expect(h.state.currentStream?.candidate, subtitlesOnly);
      verifyNeverResolved(h, englishOnly);
      expect(
        h.state.notification,
        l10n.playerNoSourceWithSoundLanguage(italian),
      );
    });

    test('a source the user picked stays, and says so', () async {
      final h = playing(
        [subtitlesOnly, englishOnly, dubbed],
        [SoundLanguage.missing],
      );
      addTearDown(h.container.dispose);

      await h.coordinator.changeSource(englishOnly);
      await pumpEventQueue();

      expect(h.state.currentStream?.candidate, englishOnly);
      verifyNeverResolved(h, dubbed);
      expect(
        h.state.notification,
        l10n.playerSourceWithoutSoundLanguage(italian),
      );
    });

    test('a file with a track that names no language stays', () async {
      final h = playing(
        [subtitlesOnly, englishOnly, dubbed],
        [SoundLanguage.unknown],
      );
      addTearDown(h.container.dispose);

      await h.coordinator.skipIfSoundLanguageMissing(isManual: false);
      await pumpEventQueue();

      expect(h.state.currentStream?.candidate, subtitlesOnly);
      verifyNeverResolved(h, dubbed);
      expect(h.state.notification, isNull);
    });
  });
}
