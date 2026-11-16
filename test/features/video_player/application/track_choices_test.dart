import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/track_choices.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockVideoController extends Mock implements VideoController {}

final _english = SubtitleTrack('1', 'English', 'eng');
final _italian = SubtitleTrack('2', 'Italiano', 'ita');

CinemaPlayerState _state({
  required SubtitleTrack playing,
  List<Map<String, String>> onDemand = const [],
}) {
  final player = _MockPlayer();
  final controller = _MockVideoController();
  when(() => controller.player).thenReturn(player);
  when(() => player.state).thenReturn(
    PlayerState(
      tracks: Tracks(
        subtitle: [
          SubtitleTrack.auto(),
          SubtitleTrack.no(),
          _english,
          _italian,
        ],
      ),
      track: Track(subtitle: playing),
    ),
  );
  final candidate = StreamCandidate(
    kind: StreamSourceKind.vod,
    title: 'Movie',
    infoHash: 'hash',
    provider: 'test',
    metadata: StreamMetadata.empty().copyWith(
      custom: {'onDemandSubtitles': onDemand},
    ),
  );
  return CinemaPlayerState(
    controller: controller,
    availableStreams: const [],
    currentStream: ResolvedStream(
      url: 'https://cdn.example/movie.m3u8',
      provider: 'test',
      candidate: candidate,
    ),
    title: 'Movie',
  );
}

void main() {
  test('the anime languages count only when split is on', () {
    const settings = UserSettings(
      playerLanguage: 'en',
      animeAudioLanguage: 'ja',
      splitAnimePreferences: true,
    );

    expect(preferredAudioLanguage(settings, isAnime: true), 'ja');
    expect(preferredAudioLanguage(settings, isAnime: false), 'en');
    expect(
      preferredAudioLanguage(
        settings.copyWith(splitAnimePreferences: false),
        isAnime: true,
      ),
      'en',
    );
  });

  // REV-173: the menu line and the panel had their own copy of this rule,
  // and named different tracks when no track was in the language.
  group('on "auto", the track that is on', () {
    test('is the first one in the preferred language', () {
      final choices = TrackChoices.subtitles(
        _state(playing: SubtitleTrack.auto()),
        'it',
      );

      expect(choices.current, _italian);
      expect(choices.tracks.where(choices.isOn), [_italian]);
    });

    test('is the first real one when none is in that language', () {
      final choices = TrackChoices.subtitles(
        _state(playing: SubtitleTrack.auto()),
        'fr',
      );

      expect(choices.current, _english);
    });
  });

  test('"off" is on when the player shows no subtitles', () {
    final choices = TrackChoices.subtitles(
      _state(playing: SubtitleTrack.no()),
      'en',
    );

    expect(choices.isOff, isTrue);
    expect(choices.tracks.where(choices.isOn), isEmpty);
  });

  // A YouTube trailer has no subtitles: nothing in the panel was ticked.
  test('"off" is on when the video has no subtitles at all', () {
    final player = _MockPlayer();
    final controller = _MockVideoController();
    when(() => controller.player).thenReturn(player);
    when(() => player.state).thenReturn(
      PlayerState(
        tracks: Tracks(subtitle: [SubtitleTrack.auto(), SubtitleTrack.no()]),
        track: Track(subtitle: SubtitleTrack.auto()),
      ),
    );
    final choices = TrackChoices.subtitles(
      CinemaPlayerState(
        controller: controller,
        availableStreams: const [],
        currentStream: null,
        title: 'Trailer',
      ),
      'it',
    );

    expect(choices.isOff, isTrue);
  });

  test('the stream\'s other subtitles come after the loaded ones', () {
    final choices = TrackChoices.subtitles(
      _state(
        playing: _english,
        onDemand: [
          // Italian is loaded already, so it is not listed twice.
          {'name': 'Italiano', 'language': 'ita', 'uri': 'https://s/it.vtt'},
          {'name': 'Español', 'language': 'spa', 'uri': 'https://s/es.vtt'},
          {'name': 'No link', 'language': 'fre', 'uri': ''},
        ],
      ),
      'en',
    );

    expect(choices.tracks.map((t) => t.id), ['1', '2', 'https://s/es.vtt']);
  });

  test('a stream\'s other subtitle is never the automatic pick', () {
    final choices = TrackChoices.subtitles(
      _state(
        playing: SubtitleTrack.auto(),
        onDemand: [
          {'name': 'Español', 'language': 'spa', 'uri': 'https://s/es.vtt'},
        ],
      ),
      'es',
    );

    expect(choices.current, _english);
  });

  test('on "auto", a forced track is never the one that is on', () {
    final forced = SubtitleTrack('7', 'Forced', 'ita');
    final player = _MockPlayer();
    final controller = _MockVideoController();
    when(() => controller.player).thenReturn(player);
    when(() => player.state).thenReturn(
      PlayerState(
        tracks: Tracks(
          subtitle: [SubtitleTrack.auto(), SubtitleTrack.no(), forced],
        ),
        track: Track(subtitle: SubtitleTrack.auto()),
      ),
    );
    final choices = TrackChoices.subtitles(
      CinemaPlayerState(
        controller: controller,
        availableStreams: const [],
        currentStream: null,
        title: 'Movie',
      ),
      'it',
    );

    expect(choices.current.id, 'auto');
    expect(choices.kindOf(forced), SubtitleKind.forced);
  });

  // A stream's other subtitle, picked: the player fetches it by its address
  // and makes a track of it. That track wasn't ticked, and the other rows in
  // its language disappeared, so the rows moved under the mouse.
  group('a stream\'s other subtitle, once the player loaded it', () {
    final picked = SubtitleTrack.uri(
      'https://s/en.vtt',
      title: 'English',
      language: 'eng',
    );
    final choices = TrackChoices.subtitles(
      _state(
        playing: picked,
        onDemand: [
          {'name': 'English', 'language': 'eng', 'uri': 'https://s/en.vtt'},
          {
            'name': 'English [CC]',
            'language': 'eng',
            'uri': 'https://s/cc.vtt',
          },
        ],
      ),
      'it',
    );

    test('is on as the track the player made of it', () {
      expect(choices.current, _english);
      expect(choices.tracks.where(choices.isOn), [_english]);
    });

    test('is listed once, and the others in its language stay', () {
      expect(choices.tracks.map((t) => t.id), ['1', 'https://s/cc.vtt', '2']);
    });
  });

  test('a stream\'s other subtitle still being fetched is on as itself', () {
    final picked = SubtitleTrack.uri(
      'https://s/fr.vtt',
      title: 'Français',
      language: 'fre',
    );
    final choices = TrackChoices.subtitles(
      _state(
        playing: picked,
        onDemand: [
          {'name': 'Français', 'language': 'fre', 'uri': 'https://s/fr.vtt'},
        ],
      ),
      'it',
    );

    expect(choices.tracks.where(choices.isOn).map((t) => t.id), [
      'https://s/fr.vtt',
    ]);
  });

  test('the file\'s own flags count, and group the list', () {
    final choices = TrackChoices.subtitles(
      _state(playing: _italian),
      'it',
      flagged: {'2': SubtitleKind.cc},
    );

    expect(choices.kindOf(_italian), SubtitleKind.cc);
    expect(choices.tracks.map((t) => t.id), ['1', '2']);
  });

  // A YouTube video's sound is a separate file the player adds by its
  // address: the player keeps the address as the track that is on, and
  // nothing in the panel was ticked.
  test('a sound added by its address is on as the track made of it', () {
    final added = AudioTrack('1', 'external', 'auto');
    final player = _MockPlayer();
    final controller = _MockVideoController();
    when(() => controller.player).thenReturn(player);
    when(() => player.state).thenReturn(
      PlayerState(
        tracks: Tracks(audio: [AudioTrack.auto(), AudioTrack.no(), added]),
        track: Track(audio: AudioTrack.uri('https://yt.example/audio.m4a')),
      ),
    );
    final choices = TrackChoices.audio(
      CinemaPlayerState(
        controller: controller,
        availableStreams: const [],
        currentStream: null,
        title: 'Trailer',
      ),
      'it',
    );

    expect(choices.current, added);
    expect(choices.tracks.where(choices.isOn), [added]);
  });

  group('the sound of a file', () {
    final italianSound = AudioTrack('1', 'Italiano', 'ita');
    final englishSound = AudioTrack('2', 'English', 'eng');
    final unnamedSound = AudioTrack('3', null, null);

    test('has the language when one track is in it', () {
      expect(
        soundLanguageOf([englishSound, italianSound], 'it'),
        SoundLanguage.present,
      );
    });

    test('misses it when every track names another language', () {
      expect(
        soundLanguageOf([AudioTrack.auto(), englishSound], 'it'),
        SoundLanguage.missing,
      );
      // The title names the language when the file's code doesn't.
      expect(
        soundLanguageOf([AudioTrack('4', 'English', 'und')], 'it'),
        SoundLanguage.missing,
      );
    });

    test('is unknown with a track that names no language', () {
      expect(
        soundLanguageOf([englishSound, unnamedSound], 'it'),
        SoundLanguage.unknown,
      );
    });

    test('is unknown before the file lists its tracks', () {
      expect(
        soundLanguageOf([AudioTrack.auto(), AudioTrack.no()], 'it'),
        SoundLanguage.unknown,
      );
    });
  });
}
