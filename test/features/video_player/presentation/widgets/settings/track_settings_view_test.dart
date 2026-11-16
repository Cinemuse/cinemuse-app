import 'dart:async';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_provider.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/track_settings_view.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/track_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockPlayer extends Mock implements Player {}

class _MockVideoController extends Mock implements VideoController {}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

/// A subtitle service with a key set: its search never ends.
class _ReadySubtitleProvider implements SubtitleProvider {
  @override
  String get name => 'OpenSubtitles.com';

  @override
  bool get isReady => true;

  @override
  Future<List<ExternalSubtitle>> search({
    String? imdbId,
    String? tmdbId,
    int? season,
    int? episode,
    String? query,
    required String language,
  }) => Completer<List<ExternalSubtitle>>().future;

  @override
  Future<String?> getDownloadUrl(ExternalSubtitle subtitle) async => null;
}

class _FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.initial, {required this.refuses});
  final CinemaPlayerState initial;
  final bool refuses;
  final picked = <Object>[];

  @override
  AsyncValue<CinemaPlayerState> build() => AsyncValue.data(initial);

  @override
  Future<void> selectTrack(Object track) async {
    if (refuses) throw const StreamingFailure('Could not turn on the track');
    picked.add(track);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// REV-173: a track the player refused still looked as if it had worked and
// said nothing.
void main() {
  const params = PlayerParams('550', 'movie');
  final italian = AudioTrack('2', 'Italiano', 'ita');

  Future<_FakePlayerController> openPanel(
    WidgetTester tester, {
    bool refuses = false,
    PlayerParams params = params,
    bool isSubtitle = false,
    AudioTrack? playing,
    List<AudioTrack>? sounds,
  }) async {
    final player = _MockPlayer();
    final controller = _MockVideoController();
    when(() => controller.player).thenReturn(player);
    when(() => player.state).thenReturn(
      PlayerState(
        tracks: Tracks(
          audio: [
            AudioTrack.auto(),
            AudioTrack.no(),
            ...(sounds ?? [AudioTrack('1', 'English', 'eng'), italian]),
          ],
        ),
        track: Track(audio: playing ?? AudioTrack('1', 'English', 'eng')),
      ),
    );
    final state = CinemaPlayerState(
      controller: controller,
      availableStreams: const [],
      currentStream: null,
      title: 'Movie',
    );
    final fake = _FakePlayerController(state, refuses: refuses);

    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          playerControllerProvider.overrideWith2((_) => fake),
          subtitleServiceProvider.overrideWithValue(
            SubtitleService([_ReadySubtitleProvider()]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TrackSettingsView(
              state: state,
              params: params,
              isSubtitle: isSubtitle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return fake;
  }

  testWidgets('a picked track is turned on, with no error', (tester) async {
    final fake = await openPanel(tester);

    await tester.tap(find.text('Italiano – Italian'));
    await tester.pumpAndSettle();

    expect(fake.picked, [italian]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused track keeps the list open and says so', (
    tester,
  ) async {
    await openPanel(tester, refuses: true);

    await tester.tap(find.text('Italiano – Italian'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't switch to this track."), findsOneWidget);
    expect(find.byType(TrackSettingsView), findsOneWidget);
  });

  // A YouTube trailer showed OpenSubtitles' part, waiting for a search that
  // never runs.
  testWidgets("a film's subtitles offer the subtitle search", (tester) async {
    await openPanel(tester, isSubtitle: true);

    expect(find.text('EXTERNAL TRACKS'), findsOneWidget);
  });

  testWidgets("a YouTube video's subtitles offer no subtitle search", (
    tester,
  ) async {
    await openPanel(
      tester,
      params: const PlayerParams('dQw4w9WgXcQ', 'youtube'),
      isSubtitle: true,
    );

    expect(find.text('EXTERNAL TRACKS'), findsNothing);
  });

  // A YouTube video's sound comes as a separate file the player adds by its
  // address: nothing in the audio panel was ticked.
  testWidgets('a sound added by its address is ticked', (tester) async {
    await openPanel(
      tester,
      params: const PlayerParams('dQw4w9WgXcQ', 'youtube'),
      playing: AudioTrack.uri('https://yt.example/audio.m4a'),
      sounds: [AudioTrack('1', 'external', 'auto')],
    );

    final ticked = tester
        .widgetList<TrackTile>(find.byType(TrackTile))
        .where((t) => t.isSelected);
    expect(ticked.map((t) => t.track.id), ['1']);
  });
}
