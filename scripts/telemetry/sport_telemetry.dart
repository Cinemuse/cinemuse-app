// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

// Use a relative import to access the actual app logic directly!
import 'package:cinemuse_app/features/home/application/sport_schedule_scraper.dart';

void main() async {
  print('Starting Sport Schedule Scraper Telemetry...');

  final dio = Dio();
  // Provide the app's existing scraper with the Dio instance
  final scraper = SportScheduleScraper(dio);

  try {
    print('Fetching sport schedule from Virgilio...');
    final events = await scraper.fetchSchedule();

    // Extract uniquely identifiable unmapped events
    final unmappedEvents = <String, Map<String, dynamic>>{};
    final sportDistribution = <String, int>{};
    int emptyChannelsCount = 0;
    int emptyNamesCount = 0;
    int nullTimesCount = 0;

    for (final event in events) {
      if (event.channels.isEmpty) emptyChannelsCount++;
      if (event.sportName.trim().isEmpty) emptyNamesCount++;
      if (event.dateTime == null) nullTimesCount++;

      final key = event.sportTranslationKey;
      sportDistribution[key] = (sportDistribution[key] ?? 0) + 1;

      if (event.sportTranslationKey == 'sport_generic') {
        final uniqueKey =
            '${event.sportName.trim()}_${event.description.trim()}';

        if (!unmappedEvents.containsKey(uniqueKey)) {
          unmappedEvents[uniqueKey] = {
            'sport_name': event.sportName.trim(),
            'description': event.description.trim(),
            'occurrences': 1,
            'time': event.dateTime?.toIso8601String(),
          };
        } else {
          final count = unmappedEvents[uniqueKey]!['occurrences'] as int;
          unmappedEvents[uniqueKey]!['occurrences'] = count + 1;
        }
      }
    }

    final unmappedList = unmappedEvents.values.toList();

    // 1. Generate JSON Report
    final report = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'health': events.length < 50 ? 'WARNING (Low Events)' : 'OK',
      'total_events_parsed': events.length,
      'empty_channels_count': emptyChannelsCount,
      'empty_names_count': emptyNamesCount,
      'null_times_count': nullTimesCount,
      'sport_distribution': sportDistribution,
      'unmapped_count': unmappedList.length,
      'unmapped_events': unmappedList,
    };

    final jsonFile = File('telemetry_report.json');
    await jsonFile.writeAsString(jsonEncode(report));

    // 2. Generate GitHub Step Summary Markdown (if running in GitHub Actions)
    final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (stepSummaryPath != null) {
      final summaryFile = File(stepSummaryPath);
      final sink = summaryFile.openWrite(mode: FileMode.append);

      sink.writeln('### Sport Scraper Telemetry Health');
      if (events.length < 50) {
        sink.writeln(
          '- **Status**: WARNING (Unusually low number of events parsed. Expected > 50)',
        );
      } else {
        sink.writeln('- **Status**: Healthy');
      }
      sink.writeln('- **Events Parsed**: ${events.length}');
      sink.writeln('- **Unmapped Sports**: ${unmappedList.length}');
      sink.writeln('- **Events with Missing Channel**: $emptyChannelsCount');
      sink.writeln('- **Events with Missing Title**: $emptyNamesCount');
      sink.writeln('- **Events with Missing Time**: $nullTimesCount');

      sink.writeln('\n#### Sport Distribution');
      sportDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..forEach((entry) {
          sink.writeln('- `${entry.key}`: ${entry.value}');
        });

      if (unmappedList.isNotEmpty) {
        sink.writeln('\n#### Unmapped Events Found');
        sink.writeln(
          'The following events matched `sport_generic` and need proper localization keys added:',
        );
        sink.writeln('');
        sink.writeln('| Sport Name | Description | Occurrences |');
        sink.writeln('| :--- | :--- | :--- |');

        for (final item in unmappedList) {
          final name = item['sport_name'];
          final desc = item['description'];
          final count = item['occurrences'];
          sink.writeln('| `$name` | $desc | $count |');
        }
      } else {
        sink.writeln('\n*All scraped events were perfectly mapped today!*');
      }

      // Append the raw JSON data in a collapsible section
      sink.writeln('\n<details>');
      sink.writeln('<summary>View Raw JSON Data</summary>\n');
      sink.writeln('```json');
      sink.writeln(const JsonEncoder.withIndent('  ').convert(report));
      sink.writeln('```');
      sink.writeln('</details>\n');

      await sink.flush();
      await sink.close();
    }

    print('Telemetry completed successfully.');
    print('Parsed: ${events.length}. Unmapped: ${unmappedList.length}');

    // If there are unmapped events, exit with code 0 (success) so it doesn't fail the build,
    // but the telemetry data is safely logged for developers to review.
    exit(0);
  } catch (e, stack) {
    print('Telemetry failed with error: $e');
    print(stack);

    // Attempt to log failure to Step Summary
    final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (stepSummaryPath != null) {
      final summaryFile = File(stepSummaryPath);
      summaryFile.writeAsStringSync(
        '### Sport Scraper Telemetry Health\n'
        '**Status**: ERROR\n\n'
        'The scraper failed to fetch or parse the schedule. The Virgilio HTML layout may have changed.\n\n'
        '```\n$e\n```',
        mode: FileMode.append,
      );
    }

    exit(1);
  }
}
