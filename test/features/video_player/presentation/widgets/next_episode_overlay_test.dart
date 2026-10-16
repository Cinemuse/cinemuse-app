import 'dart:async';

import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/presentation/widgets/next_episode_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/focus_helpers.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockVideoController extends Mock implements VideoController {}

// REV-289: the big "Next episode" button takes the focus when it slides in
// (Enter plays the next episode) and can't be focused while hidden.
void main() {
  testWidgets('hidden: not focusable; slides in: focused, Enter plays it', (
    tester,
  ) async {
    final position = StreamController<Duration>();
    addTearDown(position.close);
    final player = _MockPlayer();
    final stream = _MockPlayerStream();
    final state = _MockPlayerState();
    final controller = _MockVideoController();
    when(() => player.stream).thenReturn(stream);
    when(() => player.state).thenReturn(state);
    when(() => stream.position).thenAnswer((_) => position.stream);
    when(() => state.position).thenReturn(const Duration(minutes: 10));
    when(() => state.duration).thenReturn(const Duration(minutes: 45));
    when(() => controller.player).thenReturn(player);
    var nextPlayed = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Align(
                  alignment: Alignment.topLeft,
                  child: TextButton(onPressed: null, child: Text('Other')),
                ),
                NextEpisodeOverlay(
                  playerState: CinemaPlayerState(
                    controller: controller,
                    availableStreams: const [],
                    currentStream: null,
                    title: 'Show',
                    nextEpisode: NextEpisodeInfo(season: 1, episode: 2),
                  ),
                  onNextEpisode: () => nextPlayed++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.text('NEXT EPISODE');

    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(isFocused(button), isFalse, reason: 'hidden, Tab $i');
    }

    position.add(const Duration(minutes: 44, seconds: 50));
    await tester.pumpAndSettle();
    expect(isFocused(button), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(nextPlayed, 1);
  });
}
