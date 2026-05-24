import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/media/data/tvtime_service.dart';

/// Telemetry script to verify TVTime internal API integration.
///
/// This script checks if the sidecar proxy and HTML scraping endpoints
/// are still active and returning the expected data structures.
Future<void> main() async {
  print('Starting TVTime Telemetry Check...');
  final dio = Dio();
  final service = TvTimeService(dio);

  final results = <String, dynamic>{
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'tests': [],
  };

  int passed = 0;
  int failed = 0;

  Future<void> runTest(String name, Future<dynamic> Function() testFn) async {
    print('Testing: $name...');
    try {
      final result = await testFn();
      results['tests'].add({
        'name': name,
        'status': 'pass',
        'data': result,
      });
      passed++;
      print('  ✓ Pass');
    } catch (e, st) {
      results['tests'].add({
        'name': name,
        'status': 'fail',
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      failed++;
      print('  ✗ Fail: $e');
    }
  }

  // 1. Series Resolution (Breaking Bad - TVDB: 81189)
  await runTest('Series Resolution (TVDB: 81189)', () async {
    final uuid = await service.resolveSeriesUuid(81189);
    if (uuid == null) throw Exception('Failed to resolve series UUID');
    return {'uuid': uuid};
  });

  // 2. Series Comments
  await runTest('Series Comments', () async {
    final comments = await service.fetchSeriesComments(81189, limit: 3);
    if (comments.isEmpty) throw Exception('Failed to fetch series comments');
    return {'count': comments.length, 'first_comment': comments.first.text};
  });

  // 3. Movie Resolution (Inception - IMDB: tt1375666)
  await runTest('Movie Resolution (IMDB: tt1375666)', () async {
    final uuid = await service.resolveMovieUuid('tt1375666');
    if (uuid == null) throw Exception('Failed to resolve movie UUID');
    return {'uuid': uuid};
  });

  // 4. Movie Comments
  await runTest('Movie Comments', () async {
    final comments = await service.fetchMovieComments('tt1375666', limit: 3);
    if (comments.isEmpty) throw Exception('Failed to fetch movie comments');
    return {'count': comments.length, 'first_comment': comments.first.text};
  });

  // 5. Episode Resolution (Breaking Bad S01E01 - TVDB Show: 81189)
  await runTest('Episode Resolution (Show: 81189, S01E01)', () async {
    final uuid = await service.resolveEpisodeUuid(81189, season: 1, episode: 1);
    if (uuid == null) throw Exception('Failed to resolve episode UUID');
    return {'uuid': uuid};
  });

  // 6. Episode Comments
  await runTest('Episode Comments', () async {
    final comments = await service.fetchEpisodeComments(81189, season: 1, episode: 1, limit: 3);
    if (comments.isEmpty) throw Exception('Failed to fetch episode comments');
    return {'count': comments.length, 'first_comment': comments.first.text};
  });

  // Save full results for proof
  final proofFile = File('tvtime_telemetry_report.json');
  final report = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'health': failed == 0 ? 'OK' : (passed > 0 ? 'DEGRADED' : 'FAILED'),
    'total_tests': passed + failed,
    'successful_tests': passed,
    'results': results['tests'],
  };
  proofFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));

  // Generate GitHub Step Summary Markdown
  final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (stepSummaryPath != null) {
    final summaryFile = File(stepSummaryPath);
    final sink = summaryFile.openWrite(mode: FileMode.append);
    
    final healthStatus = failed == 0 ? 'OK' : (passed > 0 ? 'DEGRADED' : 'FAILED');

    sink.writeln('### 💬 TVTime Scraper Telemetry');
    sink.writeln('- **Status**: $healthStatus');
    sink.writeln('- **Tests Passed**: $passed / ${passed + failed}');
    
    sink.writeln('\n#### Test Results');
    sink.writeln('| Test Name | Status | Details |');
    sink.writeln('| :--- | :--- | :--- |');
    
    for (final test in results['tests'] as List) {
      final name = test['name'];
      final status = test['status'];
      final statusIcon = status == 'pass' ? '✅' : '❌';
      
      String details = '';
      if (status == 'pass') {
        if (test['data'] != null && test['data'] is Map) {
          final data = test['data'] as Map;
          if (data.containsKey('uuid')) {
             details = 'Resolved UUID: ${data['uuid']}';
          } else if (data.containsKey('count')) {
             details = 'Fetched ${data['count']} comments';
          } else {
             details = 'Success';
          }
        } else {
          details = 'Success';
        }
      } else {
         details = test['error'] ?? 'Unknown error';
      }
      
      sink.writeln('| **$name** | $statusIcon ${status.toString().toUpperCase()} | $details |');
    }
    
    if (failed > 0) {
      sink.writeln('\n> **Warning**: TVTime internal API or DOM structure may have changed. Please verify the reverse-engineered endpoints in `tvtime_service.dart`.');
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

  print('\n--- Telemetry Summary ---');
  print('Passed: $passed');
  print('Failed: $failed');
  print('Report written to: ${proofFile.path}');

  if (passed == 0) {
    exit(1);
  }
  exit(0);
