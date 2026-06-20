/// Integration test driver that captures timeline summaries
/// and writes them to a JSON file for cross-commit comparison.
///
/// Usage:
/// ```
/// flutter drive --no-dds --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf_home_scroll_test.dart \
///   --profile -d <device_id>
/// ```
///
/// Output: `build/perf_results.timeline_summary.json`
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart'
    as integration_test_driver;

Future<void> main() {
  return integration_test_driver.integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) {
        // ignore: avoid_print
        print('No timeline data received from the test.');
        return;
      }

      final summaries = <String, dynamic>{};

      for (final entry in data.entries) {
        final timeline = Timeline.fromJson(entry.value as Map<String, dynamic>);
        final summary = TimelineSummary.summarize(timeline);

        // Write the full timeline + summary for each test
        await summary.writeTimelineToFile(
          entry.key,
          destinationDirectory: 'build',
          pretty: true,
        );

        // Collect key metrics for the combined summary
        summaries[entry.key] = {
          'average_frame_build_time_millis':
              summary.computeAverageFrameBuildTimeMillis(),
          'worst_frame_build_time_millis':
              summary.computeWorstFrameBuildTimeMillis(),
          '99th_percentile_frame_build_time_millis':
              summary.computePercentileFrameBuildTimeMillis(99),
          '90th_percentile_frame_build_time_millis':
              summary.computePercentileFrameBuildTimeMillis(90),
          'average_frame_rasterizer_time_millis':
              summary.computeAverageFrameRasterizerTimeMillis(),
          'worst_frame_rasterizer_time_millis':
              summary.computeWorstFrameRasterizerTimeMillis(),
          'missed_frame_build_budget_count':
              summary.computeMissedFrameBuildBudgetCount(),
          'missed_frame_rasterizer_budget_count':
              summary.computeMissedFrameRasterizerBudgetCount(),
          'frame_count': summary.countFrames(),
        };
      }

      // Write combined summary
      final file = File('build/perf_summary.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(summaries),
      );

      // Print results to console
      // ignore: avoid_print
      print('\n${'=' * 60}');
      // ignore: avoid_print
      print('PERFORMANCE RESULTS');
      // ignore: avoid_print
      print('${'=' * 60}');
      for (final entry in summaries.entries) {
        final metrics = entry.value as Map<String, dynamic>;
        // ignore: avoid_print
        print('\n📊 ${entry.key}:');
        for (final metric in metrics.entries) {
          final value = metric.value;
          final formatted = value is double
              ? value.toStringAsFixed(2)
              : value.toString();
          // ignore: avoid_print
          print('   ${metric.key}: $formatted');
        }
      }
      // ignore: avoid_print
      print('\n${'=' * 60}\n');
    },
  );
}
