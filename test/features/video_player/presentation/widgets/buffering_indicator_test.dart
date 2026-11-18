import 'dart:async';

import 'package:cinemuse_app/features/video_player/presentation/widgets/buffering_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

void main() {
  late _MockPlayer player;
  late StreamController<bool> playing;
  late StreamController<bool> buffering;

  setUp(() {
    player = _MockPlayer();
    final stream = _MockPlayerStream();
    final state = _MockPlayerState();
    playing = StreamController<bool>.broadcast();
    buffering = StreamController<bool>.broadcast();
    when(() => player.stream).thenReturn(stream);
    when(() => player.state).thenReturn(state);
    when(() => stream.playing).thenAnswer((_) => playing.stream);
    when(() => stream.buffering).thenAnswer((_) => buffering.stream);
    when(() => state.playing).thenReturn(true);
    when(() => state.buffering).thenReturn(false);
  });

  tearDown(() async {
    await playing.close();
    await buffering.close();
  });

  Future<void> pumpIndicator(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(home: BufferingIndicator(player: player)),
  );

  Future<void> emit(WidgetTester tester, StreamController<bool> c, bool v) {
    c.add(v);
    return tester.pump();
  }

  final spinner = find.byType(CircularProgressIndicator);

  testWidgets('shows while playing and loading, hides when loaded', (
    tester,
  ) async {
    await pumpIndicator(tester);
    expect(spinner, findsNothing);

    await emit(tester, buffering, true);
    expect(spinner, findsOneWidget);

    await emit(tester, buffering, false);
    expect(spinner, findsNothing);
  });

  testWidgets('pausing while loading hides it; playing again brings it back', (
    tester,
  ) async {
    await pumpIndicator(tester);
    await emit(tester, buffering, true);
    expect(spinner, findsOneWidget);

    // The engine keeps saying "loading" while paused.
    await emit(tester, playing, false);
    expect(spinner, findsNothing);

    await emit(tester, playing, true);
    expect(spinner, findsOneWidget);

    await emit(tester, buffering, false);
    expect(spinner, findsNothing);
  });
}
