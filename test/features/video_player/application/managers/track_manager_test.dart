import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/track_choices.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier([this.settings = const UserSettings()]);

  final UserSettings settings;

  @override
  UserSettings build() => settings;
}

class _FakeSubtitleService extends Fake implements SubtitleService {
  @override
  bool get hasActiveProviders => true;

  @override
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) async => const [_subtitle];

  // Like the real service for a subtitle that carries its own link.
  @override
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle) async =>
      subtitle.url;
}

const _subtitle = ExternalSubtitle(
  id: '1',
  language: 'en',
  format: 'srt',
  providerName: 'test',
  title: 'English',
);

void main() {
  // The screen opens the player without a start position; the controller
  // fills it in, so the resolved params differ from the screen's.
  const screenParams = PlayerParams('550', 'movie');
  const resolvedParams = PlayerParams('550', 'movie', startPosition: 0);

  late ProviderContainer container;
  late Provider<TrackManager> managerProvider;
  late _MockPlayer player;
  late _MockPlayerStream playerStream;

  setUpAll(() {
    registerFallbackValue(AudioTrack.no());
    registerFallbackValue(SubtitleTrack.no());
  });

  setUp(() {
    player = _MockPlayer();
    playerStream = _MockPlayerStream();
    when(() => player.stream).thenReturn(playerStream);
    when(() => playerStream.tracks).thenAnswer((_) => const Stream.empty());
    when(() => player.state).thenReturn(const PlayerState());

    managerProvider = Provider.autoDispose((ref) {
      final manager = TrackManager(
        ref: ref,
        player: player,
        params: resolvedParams,
        subtitlesKey: screenParams,
      );
      ref.onDispose(manager.dispose);
      return manager;
    });

    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
        subtitleServiceProvider.overrideWithValue(_FakeSubtitleService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('external subtitles reach the key the screen reads (REV-142)', () async {
    container.listen(managerProvider, (_, _) {});
    await container.read(managerProvider).ensurePreferredTrack();
    await pumpEventQueue();

    final results = container.read(externalSubtitlesProvider(screenParams));
    expect(results, isA<AsyncData<List<ExternalSubtitle>>>());
    expect(results.value, [_subtitle]);
  });

  test('results are dropped when the player closes (REV-142)', () async {
    final subscription = container.listen(managerProvider, (_, _) {});
    await container.read(managerProvider).ensurePreferredTrack();
    await pumpEventQueue();

    subscription.close();
    await container.pump();

    expect(
      container.read(externalSubtitlesProvider(screenParams)),
      isA<AsyncLoading<List<ExternalSubtitle>>>(),
    );
  });

  // REV-173: the panel reported a manual pick even when the player refused
  // the track, so the preferred one never came back.
  group('a pick in the panel', () {
    final english = AudioTrack('1', 'English', 'eng');
    final italian = AudioTrack('2', 'Italiano', 'ita');
    late StreamController<Tracks> trackLists;
    late AudioTrack playing;

    setUp(() {
      trackLists = StreamController<Tracks>.broadcast();
      playing = english;
      when(() => playerStream.tracks).thenAnswer((_) => trackLists.stream);
      when(() => player.state).thenAnswer(
        (_) => PlayerState(
          tracks: Tracks(
            audio: [AudioTrack.auto(), AudioTrack.no(), english, italian],
          ),
          track: Track(audio: playing, subtitle: SubtitleTrack.no()),
        ),
      );
      when(() => player.setAudioTrack(any())).thenAnswer((invocation) async {
        playing = invocation.positionalArguments.first as AudioTrack;
      });
      when(() => player.setSubtitleTrack(any())).thenAnswer((_) async {});
    });

    tearDown(() => trackLists.close());

    Future<TrackManager> startedManager() async {
      container.listen(managerProvider, (_, _) {});
      final manager = container.read(managerProvider);
      await manager.ensurePreferredTrack();
      return manager;
    }

    test('that worked stops the automatic choice', () async {
      final manager = await startedManager();

      await manager.selectTrack(italian);
      trackLists.add(const Tracks()); // the player lists its tracks again
      await pumpEventQueue();

      expect(playing, italian);
      verifyNever(() => player.setAudioTrack(english));
    });

    test('that failed throws and leaves the automatic choice on', () async {
      final manager = await startedManager();
      when(() => player.setAudioTrack(italian)).thenThrow(Exception('stale'));

      await expectLater(
        manager.selectTrack(italian),
        throwsA(isA<StreamingFailure>()),
      );
      playing = italian; // the engine switched by itself
      trackLists.add(const Tracks());
      await pumpEventQueue();

      expect(playing, english);
    });

    test('of an external subtitle turns its link on', () async {
      final manager = await startedManager();
      const withLink = ExternalSubtitle(
        id: '2',
        language: 'it',
        format: 'srt',
        providerName: 'test',
        title: 'Italiano',
        url: 'https://subs.example/it.srt',
      );

      await manager.applyExternalSubtitle(withLink);

      final track =
          verify(() => player.setSubtitleTrack(captureAny())).captured.single
              as SubtitleTrack;
      expect(track.id, 'https://subs.example/it.srt');
      expect(track.title, 'Italiano');
    });

    test('of an external subtitle with no link fails', () async {
      final manager = await startedManager();

      await expectLater(
        manager.applyExternalSubtitle(_subtitle),
        throwsA(isA<StreamingFailure>()),
      );
      verifyNever(() => player.setSubtitleTrack(any()));
    });
  });

  // A stream's other subtitle is fetched by the player on a pick (about 5 s
  // for a long one): a second click meanwhile fetched it again, and the list
  // showed it twice; a track list that changed meanwhile undid the pick.
  group('a stream\'s other subtitle, picked', () {
    final link = SubtitleTrack.uri(
      'https://s/en.m3u8',
      title: 'English',
      language: 'eng',
    );
    final english = AudioTrack('1', 'English', 'eng');
    final italian = AudioTrack('2', 'Italiano', 'ita');
    late StreamController<Tracks> trackLists;
    late Completer<void> fetched;
    late List<SubtitleTrack> subtitles;
    late AudioTrack playing;

    setUp(() {
      trackLists = StreamController<Tracks>.broadcast();
      fetched = Completer<void>();
      subtitles = [SubtitleTrack.auto(), SubtitleTrack.no()];
      playing = english;
      when(() => playerStream.tracks).thenAnswer((_) => trackLists.stream);
      when(() => player.state).thenAnswer(
        (_) => PlayerState(
          tracks: Tracks(
            audio: [AudioTrack.auto(), AudioTrack.no(), english, italian],
            subtitle: subtitles,
          ),
          track: Track(audio: playing, subtitle: SubtitleTrack.no()),
        ),
      );
      when(() => player.setAudioTrack(any())).thenAnswer((invocation) async {
        playing = invocation.positionalArguments.first as AudioTrack;
      });
      when(
        () => player.setSubtitleTrack(any()),
      ).thenAnswer((_) => fetched.future);
    });

    tearDown(() => trackLists.close());

    Future<TrackManager> startedManager() async {
      container.listen(managerProvider, (_, _) {});
      final manager = container.read(managerProvider);
      await manager.ensurePreferredTrack();
      clearInteractions(player);
      return manager;
    }

    String? fetching() =>
        container.read(fetchingSubtitleProvider(screenParams));

    test('is fetched once, however many clicks', () async {
      final manager = await startedManager();

      final first = manager.selectTrack(link);
      await manager.selectTrack(link);
      expect(fetching(), 'https://s/en.m3u8');
      fetched.complete();
      await first;

      verify(() => player.setSubtitleTrack(link)).called(1);
      expect(fetching(), isNull);
    });

    test('once loaded, its track is turned on, not fetched again', () async {
      final manager = await startedManager();
      final loaded = SubtitleTrack('7', 'English', 'eng');
      subtitles = [...subtitles, loaded];
      fetched.complete();

      await manager.selectTrack(link);

      verify(() => player.setSubtitleTrack(loaded)).called(1);
      verifyNever(() => player.setSubtitleTrack(link));
    });

    test('a track list that changes meanwhile does not undo it', () async {
      final manager = await startedManager();
      playing = italian; // the user picked the Italian sound before

      final pick = manager.selectTrack(link);
      trackLists.add(const Tracks()); // the fetched track arrives
      await pumpEventQueue();
      fetched.complete();
      await pick;

      expect(playing, italian);
      verifyNever(() => player.setAudioTrack(english));
    });

    test('that fails clears the loading row and throws', () async {
      final manager = await startedManager();
      fetched.completeError(Exception('refused'));

      await expectLater(
        manager.selectTrack(link),
        throwsA(isA<StreamingFailure>()),
      );
      expect(fetching(), isNull);
    });
  });

  // mpv with no TrueHD decoder plays the picture in silence and reports an
  // error, which used to throw the whole source away.
  group('a sound track the engine cannot decode', () {
    const truehd = "Failed to initialize a decoder for codec 'truehd'.";
    final englishTrueHd = AudioTrack('1', 'Atmos', 'eng', codec: 'truehd');
    final englishAc3 = AudioTrack('2', 'English', 'eng', codec: 'ac3');
    final italianAc3 = AudioTrack('3', 'Italiano', 'ita', codec: 'ac3');
    late StreamController<Tracks> trackLists;
    late List<AudioTrack> fileTracks;
    late AudioTrack playing;

    setUp(() {
      trackLists = StreamController<Tracks>.broadcast();
      fileTracks = [englishTrueHd, italianAc3, englishAc3];
      playing = englishTrueHd;
      when(() => playerStream.tracks).thenAnswer((_) => trackLists.stream);
      when(() => player.state).thenAnswer(
        (_) => PlayerState(
          tracks: Tracks(
            audio: [AudioTrack.auto(), AudioTrack.no(), ...fileTracks],
          ),
          track: Track(audio: playing, subtitle: SubtitleTrack.no()),
        ),
      );
      when(() => player.setAudioTrack(any())).thenAnswer((invocation) async {
        playing = invocation.positionalArguments.first as AudioTrack;
      });
      when(() => player.setSubtitleTrack(any())).thenAnswer((_) async {});
    });

    tearDown(() => trackLists.close());

    TrackManager manager() {
      container.listen(managerProvider, (_, _) {});
      return container.read(managerProvider);
    }

    test('switches to another track, the preferred language first', () async {
      final result = manager().recoverFromAudioError(truehd);
      await pumpEventQueue();

      expect(result, AudioErrorRecovery.switchedTrack);
      expect(playing, englishAc3);
    });

    test('the automatic choice never picks that codec again', () async {
      final tracks = manager();
      tracks.recoverFromAudioError(truehd);
      await tracks.ensurePreferredTrack();
      trackLists.add(const Tracks()); // the next source lists its tracks
      await pumpEventQueue();

      verifyNever(() => player.setAudioTrack(englishTrueHd));
      expect(playing, englishAc3);
    });

    test('with no other track the source is dead', () async {
      fileTracks = [englishTrueHd];

      expect(
        manager().recoverFromAudioError(truehd),
        AudioErrorRecovery.noTrackLeft,
      );
      verifyNever(() => player.setAudioTrack(any()));
    });

    test('a video codec or a network error is left alone', () async {
      final tracks = manager();

      expect(
        tracks.recoverFromAudioError(
          "Failed to initialize a decoder for codec 'vvc'.",
        ),
        isNull,
      );
      expect(tracks.recoverFromAudioError('tcp: connection reset'), isNull);
      verifyNever(() => player.setAudioTrack(any()));
    });
  });

  // A forced track holds only what the sound doesn't say (an alien language,
  // a sign): it shows with subtitles off, and is never the subtitles on.
  group('forced subtitles', () {
    final english = AudioTrack('1', null, 'eng');
    final forcedEnglish = SubtitleTrack('3', 'English (Forced)', 'eng');
    final flaggedEnglish = SubtitleTrack('4', null, 'eng');
    final fullEnglish = SubtitleTrack('5', null, 'eng');
    final ccEnglish = SubtitleTrack('6', 'SDH', 'eng');
    late List<SubtitleTrack> subtitles;
    late SubtitleTrack showing;

    setUp(() {
      showing = SubtitleTrack.auto();
      when(() => player.state).thenAnswer(
        (_) => PlayerState(
          tracks: Tracks(
            audio: [AudioTrack.auto(), AudioTrack.no(), english],
            subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), ...subtitles],
          ),
          track: Track(audio: english, subtitle: showing),
        ),
      );
      when(() => player.setAudioTrack(any())).thenAnswer((_) async {});
      when(() => player.setSubtitleTrack(any())).thenAnswer((invocation) async {
        showing = invocation.positionalArguments.first as SubtitleTrack;
      });
    });

    Future<void> start({required bool showSubtitles}) async {
      container.dispose();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          settingsProvider.overrideWith(
            () => _FakeSettingsNotifier(
              UserSettings(showSubtitles: showSubtitles),
            ),
          ),
          subtitleServiceProvider.overrideWithValue(_FakeSubtitleService()),
        ],
      );
      container.listen(managerProvider, (_, _) {});
      await container.read(managerProvider).ensurePreferredTrack();
      await pumpEventQueue();
    }

    test('with subtitles off, the forced ones for the sound show', () async {
      subtitles = [fullEnglish, forcedEnglish];
      await start(showSubtitles: false);
      expect(showing, forcedEnglish);
    });

    test('with subtitles off and no forced track, none show', () async {
      subtitles = [fullEnglish, ccEnglish];
      await start(showSubtitles: false);
      expect(showing.id, 'no');
    });

    test('with subtitles on, the full track wins over a forced one listed '
        'first, and over the CC one', () async {
      subtitles = [forcedEnglish, ccEnglish, fullEnglish];
      await start(showSubtitles: true);
      expect(showing, fullEnglish);
    });

    test('with subtitles on and only forced and CC, the CC one', () async {
      subtitles = [forcedEnglish, ccEnglish];
      await start(showSubtitles: true);
      expect(showing, ccEnglish);
    });

    test('the file\'s flags reach the panel', () async {
      final flags = await readSubtitleFlags(
        (property) async => switch (property) {
          'track-list/count' => '3',
          'track-list/0/type' => 'video',
          'track-list/1/type' || 'track-list/2/type' => 'sub',
          'track-list/1/id' => '4',
          'track-list/2/id' => '5',
          'track-list/1/forced' => 'yes',
          'track-list/2/forced' => 'no',
          // Android's older engine doesn't know this flag.
          _ => '',
        },
      );
      expect(flags, {'4': SubtitleKind.forced});
      expect(
        await readSubtitleFlags(
          (property) async => switch (property) {
            'track-list/count' => '1',
            'track-list/0/type' => 'sub',
            'track-list/0/id' => '6',
            'track-list/0/hearing-impaired' => 'yes',
            _ => 'no',
          },
        ),
        {'6': SubtitleKind.cc},
      );
      // flaggedEnglish carries no word that says forced.
      expect(LanguageMapper.subtitleKind(flaggedEnglish), SubtitleKind.full);
    });
  });

  group('the sound language of the file now open', () {
    test('waits for the file to list its tracks', () async {
      final listed = StreamController<Tracks>.broadcast();
      addTearDown(listed.close);
      when(() => playerStream.tracks).thenAnswer((_) => listed.stream);
      container.listen(managerProvider, (_, _) {});

      final answer = container.read(managerProvider).soundLanguage('it');
      listed.add(const Tracks(audio: [])); // the file isn't read yet
      listed.add(Tracks(audio: [AudioTrack('1', 'English', 'eng')]));

      expect(await answer, SoundLanguage.missing);
    });

    test('says unknown when the tracks never come', () async {
      final never = StreamController<Tracks>.broadcast();
      addTearDown(never.close);
      when(() => playerStream.tracks).thenAnswer((_) => never.stream);
      container.listen(managerProvider, (_, _) {});
      final answer = await container
          .read(managerProvider)
          .soundLanguage('it', wait: const Duration(milliseconds: 10));

      expect(answer, SoundLanguage.unknown);
    });
  });
}
