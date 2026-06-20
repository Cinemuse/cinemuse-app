/// Home screen scroll performance benchmarks.
///
/// Measures frame timing during vertical page scrolling and
/// horizontal carousel scrolling with real TMDB data.
///
/// Run with:
/// ```
/// flutter drive --no-dds --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf_home_scroll_test.dart \
///   --profile -d <device_id>
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'app_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home vertical scroll performance', (tester) async {
    await pumpAppAndLogin(tester);
    await waitForHomeData(tester);

    // Allow images to start decoding before we benchmark
    await tester.pump(const Duration(seconds: 2));

    await binding.traceAction(
      () async {
        final scrollable = find.byType(Scrollable).first;

        for (var i = 0; i < 5; i++) {
          await tester.fling(scrollable, const Offset(0, -800), 2500);
          await tester.pumpAndSettle();

          await tester.fling(scrollable, const Offset(0, 800), 2500);
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'home_vertical_scroll',
    );
  });

  testWidgets('Home carousel horizontal scroll performance', (tester) async {
    await pumpAppAndLogin(tester);
    await waitForHomeData(tester);

    await tester.pump(const Duration(seconds: 2));

    // Ensure the first carousel is fully visible on screen
    final firstCarousel = find.byType(PosterCarouselRow).first;
    await tester.ensureVisible(firstCarousel);
    await tester.pumpAndSettle();

    await binding.traceAction(
      () async {
        // Find the horizontal scrollable inside that carousel
        final horizontalScrollables = find.descendant(
          of: firstCarousel,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.right,
          ),
        );

        if (horizontalScrollables.evaluate().isEmpty) {
          fail(
            'No horizontal Scrollable found. '
            'Ensure at least one carousel row is visible.',
          );
        }

        final carousel = horizontalScrollables.first;

        for (var i = 0; i < 5; i++) {
          await tester.fling(carousel, const Offset(-500, 0), 2500, warnIfMissed: false);
          await tester.pumpAndSettle();

          await tester.fling(carousel, const Offset(500, 0), 2500, warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'home_carousel_scroll',
    );
  });
}
