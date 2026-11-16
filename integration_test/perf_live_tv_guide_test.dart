/// Live TV guide performance benchmark.
///
/// Holds the arrow keys in the guide with the real playlist and guide, as a
/// remote's held button does: Down, Up and Right through the programs, then
/// Down through the channel column.
///
/// Run with:
/// ```
/// flutter drive --no-dds --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf_live_tv_guide_test.dart \
///   --profile -d <device_id> --dart-define-from-file=dev_login.json
/// ```
///
/// `--dart-define=KEY_GAP_MS=<ms>` sets the time between presses (50 by
/// default); `--dart-define=PROFILE_BUILDS=true` puts every widget build in
/// the timeline, to count them (the frame times are then not real).
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_program_block.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/guide/epg_timeline_grid.dart';

import 'app_test_helpers.dart';

const _gap = Duration(
  milliseconds: int.fromEnvironment('KEY_GAP_MS', defaultValue: 50),
);
const _profileBuilds = bool.fromEnvironment('PROFILE_BUILDS');

// A profile build has no key names, which the key simulator looks up.
final _physicalKeys = {
  LogicalKeyboardKey.arrowDown: PhysicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowUp: PhysicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowLeft: PhysicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight: PhysicalKeyboardKey.arrowRight,
};

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) => tester
    .sendKeyEvent(key, platform: 'android', physicalKey: _physicalKeys[key]);

/// [key] [times] times, [_gap] apart, then time for the scrolling to end.
Future<void> _hold(
  WidgetTester tester,
  LogicalKeyboardKey key,
  int times,
) async {
  for (var i = 0; i < times; i++) {
    await _press(tester, key);
    await Future<void>.delayed(_gap);
  }
  await Future<void>.delayed(const Duration(milliseconds: 600));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live TV guide held arrows performance', (tester) async {
    final container = await pumpAppAndLogin(tester);
    container.read(navIndexProvider.notifier).set(NavTab.liveTv);
    await pumpUntil(
      tester,
      () => find.byType(EpgProgramBlock).evaluate().length > 20,
      what: 'guide programs',
      timeout: const Duration(seconds: 60),
    );
    await tester.pump(const Duration(seconds: 3));

    final grid = tester.state<EpgTimelineGridState>(
      find.byType(EpgTimelineGrid),
    );
    grid.focusFromAbove();
    await tester.pump(const Duration(milliseconds: 500));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));

    // Frames as on a device, scroll animations included, not only pumped.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    debugProfileBuildsEnabled = _profileBuilds;
    const suffix = _profileBuilds ? '_builds' : '';

    await binding.traceAction(
      () => _hold(tester, LogicalKeyboardKey.arrowDown, 30),
      reportKey: 'guide_down$suffix',
    );
    await binding.traceAction(
      () => _hold(tester, LogicalKeyboardKey.arrowUp, 30),
      reportKey: 'guide_up$suffix',
    );
    await binding.traceAction(
      () => _hold(tester, LogicalKeyboardKey.arrowRight, 20),
      reportKey: 'guide_right$suffix',
    );

    grid.focusFromAbove();
    await tester.pump(const Duration(seconds: 1));
    await binding.traceAction(
      () => _hold(tester, LogicalKeyboardKey.arrowDown, 30),
      reportKey: 'guide_channels_down$suffix',
    );
    debugProfileBuildsEnabled = false;
  });
}
