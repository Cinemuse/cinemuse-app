import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();

  // TVDB ID for The Boys is 355567
  const tvdbShowId = 355567;
  const season = 1;
  const episode = 1;

  print('Fetching show page to resolve episode UUID...');

  final showUrl = 'https://www.tvtime.com/show/$tvdbShowId';
  final response = await dio.get<String>(
    showUrl,
    options: Options(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      responseType: ResponseType.plain,
    ),
  );

  final html = response.data ?? '';

  final episodePattern = RegExp(
    r'href="https://app\.tvtime\.com/show/[^/]+/episode/([0-9a-f\-]{36})"[^>]*>[^<]*'
    r'(?:<[^>]+>)*[^<]*S(\d+)\s*\|\s*E(\d+)',
    dotAll: true,
  );

  final paddedSeason = season.toString().padLeft(2, '0');
  final paddedEpisode = episode.toString().padLeft(2, '0');

  String? episodeUuid;
  for (final match in episodePattern.allMatches(html)) {
    final matchSeason = match.group(2);
    final matchEpisode = match.group(3);
    if (matchSeason == paddedSeason && matchEpisode == paddedEpisode) {
      episodeUuid = match.group(1);
      break;
    }
  }

  if (episodeUuid == null) {
    // Two-pass fallback
    final anchorPattern = RegExp(
      r'href="https://app\.tvtime\.com/show/[^/]+/episode/([0-9a-f\-]{36})"',
    );
    final labelPattern = RegExp(r'S(\d+)\s*\|\s*E(\d+)');

    final anchors = anchorPattern.allMatches(html).toList();
    final labels = labelPattern.allMatches(html).toList();

    if (anchors.length == labels.length) {
      for (int i = 0; i < anchors.length; i++) {
        final s = labels[i].group(1);
        final e = labels[i].group(2);
        if (s == paddedSeason && e == paddedEpisode) {
          episodeUuid = anchors[i].group(1);
          break;
        }
      }
    }
  }

  if (episodeUuid == null) {
    print('Failed to resolve episode UUID.');
    return;
  }

  print('Resolved UUID: $episodeUuid');

  final innerUrl =
      'https://comments.tvtime.com/v1/comments/cgw/entity/$episodeUuid/comments?sort=most_liked&limit=20';
  final encodedUrl = Uri.encodeComponent(innerUrl);
  final commentsUrl =
      'https://side-api.tvtime.com/sidecar/tvtcached?o=$encodedUrl';

  print('Fetching comments from: $commentsUrl');

  final commentsResponse = await dio.get(commentsUrl);

  // Print JSON nicely formatted
  final encoder = JsonEncoder.withIndent('  ');
  final jsonString = encoder.convert(commentsResponse.data);
  print('--- RAW JSON DATA ---');
  print(jsonString);
}
