import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/live_tv_quality_view.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/settings/selectable_option_tile.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

import '../../../../../helpers/focus_helpers.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _MockVideoController extends Mock implements mkv.VideoController {}

class _FakePlayerController extends Notifier<AsyncValue<CinemaPlayerState>>
    implements PlayerController {
  _FakePlayerController(this.initial);
  final CinemaPlayerState initial;
  final switched = <StreamLink>[];
  final pickedSizes = <int>[];

  @override
  AsyncValue<CinemaPlayerState> build() => AsyncValue.data(initial);

  @override
  Future<void> switchLiveSource(StreamLink link) async => switched.add(link);

  /// Like the player: the pick shows in the state.
  @override
  void pickPictureSize(int height) {
    pickedSizes.add(height);
    final current = state.requireValue;
    final sizes = current.live.pictureSizes;
    state = AsyncValue.data(
      current.copyWith(
        live: LivePlayback(
          channel: current.live.channel,
          pictureSizes: LivePictureSizes(
            heights: sizes.heights,
            picked: height,
            playing: sizes.playing,
          ),
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _hd = StreamLink(
  url: 'https://example.com/hd.m3u8',
  quality: StreamQuality.hd,
  provider: 'Backup',
);

/// Opens the view over a "Player" page; with [links] the channel has those
/// sources, and with [sizes] its stream holds those picture sizes. Returns
/// the player's fake.
Future<_FakePlayerController> _openView(
  WidgetTester tester, {
  List<StreamLink> links = const [],
  StreamLink? playing,
  LivePictureSizes sizes = const LivePictureSizes(),
}) async {
  final state = CinemaPlayerState(
    controller: _MockVideoController(),
    availableStreams: const [],
    currentStream: null,
    title: 'Rai 1',
    live: LivePlayback(
      channel: Channel(lcn: 1, name: 'Rai 1', logo: '', links: links),
      link: playing,
      pictureSizes: sizes,
    ),
  );
  final player = _FakePlayerController(state);
  const params = PlayerParams('livetv_session', 'livetv');
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [playerControllerProvider.overrideWith2((_) => player)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: LiveTvQualityView(state: state, params: params),
                ),
              ),
            ),
            child: const Text('Player'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Player'));
  await tester.pumpAndSettle();
  return player;
}

bool _isTicked(WidgetTester tester, String label) => tester
    .widget<SelectableOptionTile>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(SelectableOptionTile),
      ),
    )
    .isSelected;

void main() {
  testWidgets('a source row shows only its name', (tester) async {
    await _openView(tester, links: [_hd]);

    expect(find.text('SOURCE'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('HD'), findsNothing);
    expect(find.text('HLS'), findsNothing);
  });

  // Purple text on the purple fill was hard to read; the top bar's is white.
  testWidgets('the source and the size in use read in white', (tester) async {
    await _openView(
      tester,
      links: [_hd],
      playing: _hd,
      sizes: const LivePictureSizes(heights: [1080], playing: 1080),
    );

    for (final label in ['Backup', '1080p']) {
      expect(
        tester.widget<Text>(find.text(label)).style?.color,
        AppTheme.textWhite,
        reason: label,
      );
    }
  });

  // REV-333: the stream reloads, so the panel closes.
  testWidgets('picking a source switches to it and closes the list', (
    tester,
  ) async {
    final player = await _openView(tester, links: [_hd]);

    await tester.tap(find.text(_hd.displayProvider));
    await tester.pumpAndSettle();

    expect(player.switched, [_hd]);
    expect(find.byType(LiveTvQualityView), findsNothing);
  });

  group('picture size', () {
    const raiSizes = LivePictureSizes(heights: [1080, 720, 432], playing: 1080);

    testWidgets('lists each size, no Auto; the biggest ticked and focused', (
      tester,
    ) async {
      await _openView(tester, links: [_hd], sizes: raiSizes);

      expect(find.text('QUALITY'), findsOneWidget);
      for (final label in ['1080p', '720p', '432p']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('Auto'), findsNothing);
      expect(_isTicked(tester, '1080p'), isTrue);
      expect(_isTicked(tester, '720p'), isFalse);
      expect(isFocused(find.text('1080p')), isTrue);
    });

    testWidgets('a pick keeps the panel open with the tick on it', (
      tester,
    ) async {
      final player = await _openView(tester, sizes: raiSizes);

      await tester.tap(find.text('432p'));
      await tester.pumpAndSettle();

      expect(player.pickedSizes, [432]);
      expect(find.byType(LiveTvQualityView), findsOneWidget);
      expect(_isTicked(tester, '432p'), isTrue);
      expect(_isTicked(tester, '1080p'), isFalse);

      await tester.tap(find.text('1080p'));
      await tester.pumpAndSettle();

      expect(player.pickedSizes, [432, 1080]);
      expect(_isTicked(tester, '1080p'), isTrue);
    });

    testWidgets('one size: that row alone, ticked', (tester) async {
      await _openView(
        tester,
        sizes: const LivePictureSizes(heights: [2160], playing: 2160),
      );

      expect(_isTicked(tester, '2160p'), isTrue);
      expect(find.textContaining('Auto'), findsNothing);
    });

    testWidgets('sizes not known: no quality list', (tester) async {
      await _openView(tester, links: [_hd]);

      expect(find.text('QUALITY'), findsNothing);
    });
  });
}
