/// Tab navigation cycle performance benchmark.
///
/// Measures frame timing stability across repeated tab switches
/// (Home → Explore → Live TV → Profile → Home) to catch:
/// - Transition animation jank
/// - Memory-related slowdowns from IndexedStack keeping screens alive
/// - Widget tree growth from providers not cleaning up
///
/// Run with:
/// ```
/// flutter drive --no-dds --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf_navigation_cycle_test.dart \
///   --profile -d <device_id>
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/features/navigation/nav_providers.dart';

import 'app_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Tab navigation cycle performance', (tester) async {
    final container = await pumpAppAndLogin(tester);
    await waitForHomeData(tester);

    // Let the initial home screen fully settle
    await tester.pump(const Duration(seconds: 2));

    await binding.traceAction(
      () async {
        for (var cycle = 0; cycle < 5; cycle++) {
          // Home (0) → Explore (1) → Live TV (2) → Profile (3) → Home (0)
          for (final tabIndex in [1, 2, 3, 0]) {
            container.read(navIndexProvider.notifier).state = tabIndex;
            await tester.pumpAndSettle(const Duration(milliseconds: 500));
          }
        }
      },
      reportKey: 'tab_navigation_cycle',
    );
  });
}
