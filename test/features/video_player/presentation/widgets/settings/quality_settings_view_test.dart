import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/player_settings_bottom_sheet.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/quality_settings_view.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

class _MockVideoController extends Mock implements VideoController {}

class _FakePlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(CinemaPlayerState state)
    : super(AsyncValue.data(state));

  final sources = <StreamCandidate>[];
  final files = <int>[];

  @override
  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) async => sources.add(candidate);

  @override
  Future<void> changeFile(int fileId) async => files.add(fileId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StreamCandidate _candidate(String title) => StreamCandidate(
  kind: StreamSourceKind.vod,
  title: title,
  infoHash: title,
  provider: 'Torrentio',
);

// REV-283: picking a source or a file left the sheet open while the keys
// went to the player behind it; now the sheet closes (PROJECT.md → Player).
void main() {
  const params = PlayerParams('1399', 'tv');
  final first = _candidate('Show S01 1080p');
  final second = _candidate('Show S01 720p');
  late _FakePlayerController fake;

  Future<void> openSheet(WidgetTester tester) async {
    final state = CinemaPlayerState(
      controller: _MockVideoController(),
      availableStreams: [first, second],
      currentStream: ResolvedStream(
        url: 'https://example.com/e1.mkv',
        provider: 'Torrentio',
        candidate: first,
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
        overrides: [playerControllerProvider.overrideWith((ref, p) => fake)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PlayerSettingsBottomSheet.show(
                  context,
                  state,
                  params,
                  (_) {},
                  initialView: SettingsView.quality,
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

  testWidgets('picking another source closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(second.title).last);
    await tester.pumpAndSettle();

    expect(fake.sources, [second]);
    expect(find.byType(QualitySettingsView), findsNothing);
  });

  testWidgets('picking another file of the pack closes the sheet', (
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

  testWidgets('the current source keeps the sheet open', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(first.title).last);
    await tester.pumpAndSettle();

    expect(fake.sources, isEmpty);
    expect(find.byType(QualitySettingsView), findsOneWidget);
  });
}
