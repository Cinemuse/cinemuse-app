import 'package:cinemuse_app/features/video_player/presentation/widgets/player_seekbar.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _liveLength = Duration(minutes: 50);

Widget _host(Widget seekbar) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, child: seekbar)),
  ),
);

/// Hovers the bar at [fraction], then clicks there. Returns the texts shown
/// while hovering.
Future<List<String?>> _hoverThenClick(
  WidgetTester tester,
  double fraction,
) async {
  final bar = tester.getRect(find.byType(Slider));
  final point = Offset(bar.left + bar.width * fraction, bar.center.dy);

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(point);
  await tester.pump();
  final hovered = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .toList();
  await mouse.down(point);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  return hovered;
}

void main() {
  test('times read like a player clock', () {
    expect(formatPlaybackTime(Duration.zero), '0:00');
    expect(formatPlaybackTime(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(
      formatPlaybackTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  // REV-288: the time shown while hovering is where a click jumps to, also
  // near both ends of the bar.
  for (final (name, fraction) in [('start', 0.1), ('end', 0.9)]) {
    testWidgets('film: hover time = click time near the $name', (tester) async {
      double? clicked;
      await tester.pumpWidget(
        _host(
          VodSeekbar(
            position: Duration.zero,
            duration: const Duration(minutes: 50),
            onChangeStart: (_) {},
            onChanged: (_) {},
            onChangeEnd: (v) => clicked = v,
          ),
        ),
      );

      final hovered = await _hoverThenClick(tester, fraction);

      expect(clicked, isNotNull);
      expect(
        hovered,
        contains(formatPlaybackTime(Duration(seconds: clicked!.toInt()))),
      );
    });

    testWidgets('live TV: hover time = click time near the $name', (
      tester,
    ) async {
      double? clicked;
      await tester.pumpWidget(
        _host(
          LiveTvSeekbar(
            rawDuration: _liveLength,
            position: _liveLength,
            dragging: false,
            onChangeStart: (_) {},
            onChanged: (_) {},
            onChangeEnd: (v) => clicked = v,
          ),
        ),
      );

      final hovered = await _hoverThenClick(tester, fraction);

      expect(clicked, isNotNull);
      final behind = _liveLength - Duration(seconds: clicked!.toInt());
      expect(hovered, contains('-${formatPlaybackTime(behind)}'));
    });
  }

  testWidgets('live TV: shows LIVE at the end, or how far behind', (
    tester,
  ) async {
    Widget seekbar(Duration position) => _host(
      LiveTvSeekbar(
        rawDuration: _liveLength,
        position: position,
        dragging: false,
        onChangeStart: (_) {},
        onChanged: (_) {},
        onChangeEnd: (_) {},
      ),
    );

    await tester.pumpWidget(seekbar(_liveLength));
    expect(find.text('LIVE'), findsOneWidget);

    await tester.pumpWidget(seekbar(_liveLength - const Duration(minutes: 2)));
    expect(find.text('-2:00'), findsOneWidget);
  });

  testWidgets('live TV: Left steps 30 seconds back, Right comes back', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    final targets = <double>[];
    final behind = _liveLength - const Duration(minutes: 5);
    await tester.pumpWidget(
      _host(
        LiveTvSeekbar(
          rawDuration: _liveLength,
          position: behind,
          dragging: false,
          seekbarFocusNode: focusNode,
          onChangeStart: (_) {},
          onChanged: (_) {},
          onChangeEnd: targets.add,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(targets, [
      (behind.inSeconds - 30).toDouble(),
      (behind.inSeconds + 30).toDouble(),
    ]);
  });
}
