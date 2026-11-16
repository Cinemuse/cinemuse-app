import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/video_top_bar.dart';
import 'package:cinemuse_app/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:mocktail/mocktail.dart';

class _MockVideoController extends Mock implements mkv.VideoController {}

final _channel = Channel(lcn: 1, name: 'Rai 1', logo: '');

/// The top bar of a live channel whose picture is [playing] pixels tall.
Future<void> _pumpLiveBar(WidgetTester tester, {int? playing}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localizationsProvider.overrideWithValue(AppLocalizationsEn()),
        currentProgramProvider.overrideWith((ref, channel) => null),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VideoTopBar(
            playerState: CinemaPlayerState(
              controller: _MockVideoController(),
              availableStreams: const [],
              currentStream: null,
              title: 'Rai 1',
              isLive: true,
              live: LivePlayback(
                channel: _channel,
                pictureSizes: LivePictureSizes(
                  heights: const [1080, 720],
                  playing: playing,
                ),
              ),
            ),
            params: const PlayerParams('livetv_session', 'livetv'),
            channel: _channel,
            isLive: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a live channel shows the picture size on screen now', (
    tester,
  ) async {
    await _pumpLiveBar(tester, playing: 720);

    expect(find.text('Rai 1'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
  });

  testWidgets('no size before the picture arrives', (tester) async {
    await _pumpLiveBar(tester);

    expect(find.textContaining(RegExp(r'\d+p$')), findsNothing);
  });
}
