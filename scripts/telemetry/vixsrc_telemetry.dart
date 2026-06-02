import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import 'package:cinemuse_app/core/services/streaming/sources/vixsrc_source.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';

void main() async {
  print('Starting VixSrc Scraper Telemetry...');
  
  final dio = Dio();
  final scraper = VixSrcSource(dio);
  
  // Define our test cases
  final testCases = [
    StreamSearchContext(
      tmdbId: '27205',
      imdbId: 'tt1375666',
      title: 'Inception',
      type: 'movie',
    ),
    StreamSearchContext(
      tmdbId: '1399',
      imdbId: 'tt0944947',
      title: 'Game of Thrones',
      type: 'tv',
      season: 1,
      episode: 1,
    ),
  ];
  
  final results = <String, Map<String, dynamic>>{};
  int successfulChecks = 0;
  
  for (final context in testCases) {
    print('Testing ${context.type.toUpperCase()}: ${context.title}...');
    try {
      final candidates = await scraper.search(context);
      
      if (candidates.isNotEmpty) {
        successfulChecks++;
        final c = candidates.first;
        final urlStr = c.url ?? '';
        
        bool subtitleTestPassed = false;
        String subtitleError = 'No subtitles found to test';
        
        // --- SUBTITLE DRY TEST LOGIC ---
        try {
          // 1. Fetch the main playlist
          final playlistRes = await dio.get(urlStr, options: Options(headers: c.headers));
          final playlistBody = playlistRes.data.toString();
          
          // 2. Look for subtitle URIs
          final subMatches = RegExp(r'#EXT-X-MEDIA:TYPE=SUBTITLES.*URI="([^"]+)"').allMatches(playlistBody);
          if (subMatches.isNotEmpty) {
            // Found subtitles, let's try to download the first one
            final subUriStr = subMatches.first.group(1)!;
            
            // Handle relative URIs
            Uri subUri = Uri.parse(subUriStr);
            if (!subUri.isAbsolute) {
              final baseUri = Uri.parse(urlStr);
              subUri = baseUri.resolve(subUriStr);
            }
            
            // 3. Attempt to fetch the subtitle playlist
            final subRes = await dio.get(subUri.toString(), options: Options(headers: c.headers));
            if (subRes.statusCode == 200) {
              final subPlaylistContent = subRes.data as String;
              print('Subtitle Playlist Content:\n$subPlaylistContent\n');
              
              // Find the first segment (usually .vtt or .m4s or .ts)
              final segmentLine = subPlaylistContent.split('\n').firstWhere((line) => line.trim().isNotEmpty && !line.startsWith('#'), orElse: () => '');
              
              if (segmentLine.isNotEmpty) {
                Uri segmentUri = Uri.parse(segmentLine);
                if (!segmentUri.isAbsolute) {
                  segmentUri = subUri.resolve(segmentLine);
                }
                
                print('Fetching subtitle segment: $segmentUri');
                final segRes = await dio.get(segmentUri.toString());
                if (segRes.statusCode == 200) {
                  subtitleTestPassed = true;
                  subtitleError = 'None';
                  
                  final segData = segRes.data is String ? segRes.data as String : 'Binary data';
                  print('Subtitle Segment Content:\n$segData\n');
                } else {
                  subtitleError = 'Segment HTTP ${segRes.statusCode}';
                }
              } else {
                subtitleError = 'No segments found in sub playlist';
              }
            } else {
              subtitleError = 'Playlist HTTP ${subRes.statusCode}';
            }
          }
        } catch (e) {
          subtitleError = e.toString();
        }
        // -------------------------------
        
        results[context.title] = {
          'status': 'SUCCESS',
          'candidates_found': candidates.length,
          'sample_url': urlStr.length > 50 ? '${urlStr.substring(0, 50)}...' : urlStr,
          'languages': c.metadata?.languages ?? [],
          'subtitle_test': subtitleTestPassed ? 'PASSED' : 'FAILED',
          'subtitle_error': subtitleError,
        };
      } else {
        results[context.title] = {
          'status': 'FAILED',
          'error': 'No streams found. The parsing logic or embed HTML might have changed.',
        };
      }
    } catch (e) {
      results[context.title] = {
        'status': 'ERROR',
        'error': e.toString(),
      };
    }
    // Small delay to prevent rate limiting
    await Future.delayed(const Duration(seconds: 1));
  }
  
  final healthStatus = successfulChecks == testCases.length ? 'OK' : (successfulChecks > 0 ? 'DEGRADED' : 'FAILED');
  
  // 1. Generate JSON Report
  final report = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'health': healthStatus,
    'total_tests': testCases.length,
    'successful_tests': successfulChecks,
    'results': results,
  };
  
  final jsonFile = File('vixsrc_telemetry_report.json');
  await jsonFile.writeAsString(jsonEncode(report));
  
  // 2. Generate GitHub Step Summary Markdown
  final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (stepSummaryPath != null) {
    final summaryFile = File(stepSummaryPath);
    final sink = summaryFile.openWrite(mode: FileMode.append);
    
    sink.writeln('### 🍿 VixSrc Scraper Telemetry');
    sink.writeln('- **Status**: $healthStatus');
    sink.writeln('- **Tests Passed**: $successfulChecks / ${testCases.length}');
    
    sink.writeln('\n#### Test Results');
    sink.writeln('| Title | Status | Candidates | Languages | Subtitles | Notes |');
    sink.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');
    
    for (final entry in results.entries) {
      final title = entry.key;
      final data = entry.value;
      
      final statusIcon = data['status'] == 'SUCCESS' ? '✅' : '❌';
      final candidates = data['candidates_found'] ?? 0;
      final langs = (data['languages'] as List<dynamic>?)?.join(', ') ?? '';
      final subTest = data['subtitle_test'] == 'PASSED' ? '✅' : '❌ (${data['subtitle_error']})';
      final notes = data['status'] == 'SUCCESS' ? 'URL parsed correctly' : (data['error'] ?? 'Unknown error');
      
      sink.writeln('| **$title** | $statusIcon ${data['status']} | $candidates | $langs | $subTest | $notes |');
    }
    
    if (healthStatus != 'OK') {
      sink.writeln('\n> **Warning**: VixSrc might have updated their token generation logic or changed their HTML layout. Please review the scraper.');
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
  
  print('Telemetry completed: $successfulChecks/${testCases.length} successful.');
  
  // Exit with error if ALL tests failed (scraper is completely broken)
  if (successfulChecks == 0) {
    exit(1);
  }
  exit(0);
}
