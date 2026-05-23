import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import 'package:cinemuse_app/core/services/streaming/sources/animeunity_source.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/anime/models/kitsu_mapping.dart';
import 'package:cinemuse_app/core/services/anime/interfaces/anime_unity_mapping_provider.dart';
import 'package:cinemuse_app/core/services/anime/models/anime_unity_entry.dart';

class MockAnimeUnityMappingProvider implements AnimeUnityMappingProvider {
  final Dio dio;
  MockAnimeUnityMappingProvider(this.dio);
  
  @override
  Future<List<AnimeUnityEntry>> getAnimeUnityIds(String kitsuId) async {
    final res = await dio.get('https://animemapping.stremio.dpdns.org/kitsu/$kitsuId');
    if (res.statusCode != 200 || res.data == null) return [];
    
    final paths = res.data['mappings']?['animeunity'] as List?;
    if (paths == null) return [];
    
    final results = <AnimeUnityEntry>[];
    final idPattern = RegExp(r'/anime/(\d+)');
    
    for (final raw in paths) {
      final path = raw.toString();
      final match = idPattern.firstMatch(path);
      if (match != null) {
        final id = int.tryParse(match.group(1)!);
        if (id != null) {
          results.add(AnimeUnityEntry(id: id, path: path));
        }
      }
    }
    return results;
  }
}

void main() async {
  print('Starting AnimeUnity Scraper Telemetry...');
  
  final dio = Dio();
  final mappingProvider = MockAnimeUnityMappingProvider(dio);
  final scraper = AnimeUnitySource(dio, mappingProvider);
  
  // Define our test cases
  final testCases = [
    StreamSearchContext(
      tmdbId: '0',
      title: 'Solo Leveling',
      type: 'tv',
      isAnime: true,
      mapping: KitsuMapping(
        kitsuId: '47053',
        absoluteEpisode: 1,
      ),
    ),
    StreamSearchContext(
      tmdbId: '0',
      title: 'Jujutsu Kaisen',
      type: 'tv',
      isAnime: true,
      mapping: KitsuMapping(
        kitsuId: '42765',
        absoluteEpisode: 1,
      ),
    ),
    StreamSearchContext(
      tmdbId: '0',
      title: 'Attack on Titan',
      type: 'tv',
      isAnime: true,
      mapping: KitsuMapping(
        kitsuId: '7442',
        absoluteEpisode: 1,
      ),
    ),
  ];
  
  final results = <String, Map<String, dynamic>>{};
  int successfulChecks = 0;
  
  for (final context in testCases) {
    print('Testing ANIME: ${context.title} (Kitsu: ${context.mapping?.kitsuId})...');
    try {
      final candidates = await scraper.search(context);
      
      if (candidates.isNotEmpty) {
        successfulChecks++;
        final c = candidates.first;
        final urlStr = c.url ?? '';
        results[context.title] = {
          'status': 'SUCCESS',
          'candidates_found': candidates.length,
          'sample_url': urlStr.length > 50 ? '${urlStr.substring(0, 50)}...' : urlStr,
          'languages': c.metadata?.languages ?? [],
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
  
  final jsonFile = File('animeunity_telemetry_report.json');
  await jsonFile.writeAsString(jsonEncode(report));
  
  // 2. Generate GitHub Step Summary Markdown
  final stepSummaryPath = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (stepSummaryPath != null) {
    final summaryFile = File(stepSummaryPath);
    final sink = summaryFile.openWrite(mode: FileMode.append);
    
    sink.writeln('### ⛩️ AnimeUnity Scraper Telemetry');
    sink.writeln('- **Status**: $healthStatus');
    sink.writeln('- **Tests Passed**: $successfulChecks / ${testCases.length}');
    
    sink.writeln('\n#### Test Results');
    sink.writeln('| Title | Status | Candidates | Languages | Notes |');
    sink.writeln('| :--- | :--- | :--- | :--- | :--- |');
    
    for (final entry in results.entries) {
      final title = entry.key;
      final data = entry.value;
      
      final statusIcon = data['status'] == 'SUCCESS' ? '✅' : '❌';
      final candidates = data['candidates_found'] ?? 0;
      final langs = (data['languages'] as List<dynamic>?)?.join(', ') ?? '';
      final notes = data['status'] == 'SUCCESS' ? 'Stream parsed correctly' : (data['error'] ?? 'Unknown error');
      
      sink.writeln('| **$title** | $statusIcon ${data['status']} | $candidates | $langs | $notes |');
    }
    
    if (healthStatus != 'OK') {
      sink.writeln('\n> **Warning**: AnimeUnity might have updated their token generation logic or changed their HTML layout (VixCloud). Please review the scraper.');
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
