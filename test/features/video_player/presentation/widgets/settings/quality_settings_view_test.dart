import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_panel.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/quality_settings_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockVideoController extends Mock implements VideoController {}

class _FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.initial);
  final CinemaPlayerState initial;

  @override
  AsyncValue<CinemaPlayerState> build() => AsyncValue.data(initial);

  final sources = <StreamCandidate>[];
  final files = <int>[];

  @override
  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) async => sources.add(candidate);

  @override
  Future<void> changeFile(int fileId) async => files.add(fileId);

  void fail(Object error) => state = AsyncValue.error(error, StackTrace.empty);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StreamCandidate _candidate(String title) => StreamCandidate(
  kind: StreamSourceKind.vod,
  title: title,
  infoHash: title,
  provider: 'Torrentio',
);

// REV-283: picking a source or a file left the panel open while the keys
// went to the player behind it; now the panel closes.
void main() {
  const params = PlayerParams('1399', 'tv');
  final first = _candidate('Show S01 1080p');
  final second = _candidate('Show S01 720p');
  late _FakePlayerController fake;

  Future<void> openSheet(
    WidgetTester tester, {
    List<StreamCandidate>? sources,
    StreamCandidate? playing,
  }) async {
    final state = CinemaPlayerState(
      controller: _MockVideoController(),
      availableStreams: sources ?? [first, second],
      currentStream: ResolvedStream(
        url: 'https://example.com/e1.mkv',
        provider: 'Torrentio',
        candidate: playing ?? first,
        activeFileId: 1,
        files: const [
          {'id': 1, 'path': 'Show/Show.S01E01.mkv', 'bytes': 1000},
          {'id': 2, 'path': 'Show/Show.S01E02.mkv', 'bytes': 1000},
        ],
      ),
      title: 'Show',
    );
    fake = _FakePlayerController(state);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [playerControllerProvider.overrideWith2((_) => fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PlayerSettingsPanel.show(
                  context,
                  state,
                  params,
                  kind: PlayerSettingsKind.source,
                ),
                child: const Text('Settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(QualitySettingsView), findsOneWidget);
  }

  testWidgets('picking another source closes the panel', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(second.title).last);
    await tester.pumpAndSettle();

    expect(fake.sources, [second]);
    expect(find.byType(QualitySettingsView), findsNothing);
  });

  testWidgets('picking another file of the pack closes the panel', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('FILES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show.S01E02.mkv'));
    await tester.pumpAndSettle();

    expect(fake.files, [2]);
    expect(find.byType(QualitySettingsView), findsNothing);
  });

  testWidgets('the current source keeps the panel open', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(first.title).last);
    await tester.pumpAndSettle();

    expect(fake.sources, isEmpty);
    expect(find.byType(QualitySettingsView), findsOneWidget);
  });

  // REV-333: the panel built every source at once and opened slowly on a
  // title with hundreds of them.
  testWidgets('a long list builds only the rows in sight and opens on the '
      'playing source', (tester) async {
    final sources = [for (var i = 0; i < 300; i++) _candidate('Source $i')];
    await openSheet(tester, sources: sources, playing: sources[200]);

    final playing = find.text('Source 200').last;
    expect(isFocused(playing), isTrue);
    final view = tester.getRect(find.byType(QualitySettingsView));
    expect(view.contains(tester.getCenter(playing)), isTrue);
    expect(find.text('Source 0'), findsNothing);
    expect(find.text('Source 299'), findsNothing);

    // The rows above it are there to scroll back to.
    await tester.drag(playing, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Source 198'), findsWidgets);
  });

  // A release word describes the stream: it must not look like a warning.
  testWidgets('a release word on a row is not in the warning colour', (
    tester,
  ) async {
    final extended = _candidate('Show S01 1080p').copyWith(
      metadata: StreamMetadata.empty().copyWith(flags: [ReleaseFlag.extended]),
    );
    await openSheet(tester, sources: [extended], playing: extended);

    final color = tester.widget<Text>(find.text('EXTENDED')).style!.color!;
    expect(color.withValues(alpha: 1), isNot(AppTheme.warning));
  });

  group('a row shows', () {
    Future<void> openRow(WidgetTester tester, StreamCandidate row) =>
        openSheet(tester, sources: [row], playing: row);

    StreamCandidate withMetadata(StreamMetadata metadata) =>
        _candidate('Show').copyWith(metadata: metadata);

    testWidgets('the picture size by its friendly name', (tester) async {
      for (final (resolution, name) in [
        (VideoResolution.r2160p, '4K'),
        (VideoResolution.r1440p, '2K'),
        (VideoResolution.r1080p, 'FHD'),
        (VideoResolution.r720p, 'HD'),
        (VideoResolution.r480p, 'SD'),
      ]) {
        final row = withMetadata(
          StreamMetadata(
            video: VideoMetadata(resolution: resolution),
            audio: const AudioMetadata(),
          ),
        );
        await openRow(tester, row);
        expect(find.text(name), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('MULTI once, and not the details it leaves out', (
      tester,
    ) async {
      await openRow(
        tester,
        withMetadata(
          const StreamMetadata(
            video: VideoMetadata(is10Bit: true),
            audio: AudioMetadata(formats: [AudioFormat.atmos]),
            flags: [
              ReleaseFlag.proper,
              ReleaseFlag.repack,
              ReleaseFlag.multi,
              ReleaseFlag.dual,
            ],
            languages: ['MULTI'],
          ),
        ),
      );

      expect(find.text('MULTI'), findsOneWidget);
      for (final hidden in ['10BIT', 'PROPER', 'REPACK', 'DUAL']) {
        expect(find.text(hidden), findsNothing);
      }
      expect(find.text('DOLBY ATMOS'), findsNothing);
    });

    testWidgets('the size a source gives apart from the name', (tester) async {
      final fromFeed = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Show',
        infoHash: 'hash',
        provider: 'Anime',
        metadata: StreamMetadata.empty(),
        sizeInBytes: 1610612736,
      );
      await openRow(tester, fromFeed);

      expect(find.text('1.5 GB'), findsOneWidget);
    });

    testWidgets('the size in the name before the one given apart', (
      tester,
    ) async {
      final both = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Show',
        infoHash: 'hash',
        provider: 'Anime',
        metadata: StreamMetadata.empty().copyWith(size: '8.4 GB'),
        sizeInBytes: 1610612736,
      );
      await openRow(tester, both);

      expect(find.text('8.4 GB'), findsOneWidget);
      expect(find.text('1.5 GB'), findsNothing);
    });
  });

  // REV-328: the player failing (no source left) while the panel was open
  // threw the error while building the panel.
  testWidgets('the player failing keeps the panel drawn', (tester) async {
    await openSheet(tester);

    fake.fail(Exception('No source left'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(second.title), findsWidgets);
  });
}
