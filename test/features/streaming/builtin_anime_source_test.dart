import 'dart:convert';

import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/features/streaming/anime/interfaces/builtin_anime_lookup.dart';
import 'package:cinemuse_app/features/streaming/anime/models/builtin_anime_entry.dart';
import 'package:cinemuse_app/features/streaming/anime/models/anime_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:cinemuse_app/features/streaming/sources/builtin_anime_source.dart';
import 'package:cinemuse_app/features/streaming/models/stream_search_context.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class MockDio extends Mock implements Dio {}

class MockBuiltInAnimeLookup extends Mock implements BuiltInAnimeLookup {}

const _site = 'https://anime.example';

BuiltInAnimeEntries _entryAt(String siteAddress) => BuiltInAnimeEntries(
  siteAddress: siteAddress,
  entries: [BuiltInAnimeEntry(id: 999, path: '/anime/999-test')],
);

Response<T> _answer<T>(T data) =>
    Response<T>(requestOptions: RequestOptions(), statusCode: 200, data: data);

/// An episode of the anime's episode list, with one video per language.
Map<String, dynamic> _episode(
  int number,
  Map<String, int> videos, {
  bool hidden = false,
}) => {
  'id': 5000 + number,
  'number': '$number',
  'videos': [
    for (final MapEntry(key: language, value: id) in videos.entries)
      {'id': id, 'language': language, 'scws_id': id + 1, 'is_hidden': hidden},
  ],
};

/// The site's episode page, its data in the root element as the site writes
/// it (HTML-escaped).
String _episodePage(String? embedUrl) {
  final data = jsonEncode({
    'component': 'Anime',
    'props': {'embedUrl': ?embedUrl},
  });
  final escaped = const HtmlEscape(HtmlEscapeMode.attribute).convert(data);
  return '<html><body><div id="app" data-page="$escaped"></div></body></html>';
}

String _videoPage(String id) =>
    '''
  <script>
    window.video = { id: '$id' };
    window.masterPlaylist = {
      params: { 'token': 'tok-$id', 'expires': '123456', 'asn': '' },
      url: 'https://videos.example/playlist/$id',
    }
    window.canPlayFHD = true
  </script>
''';

const _masterPlaylist = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=854x480
https://videos.example/playlist/1?type=video&rendition=480p
#EXT-X-STREAM-INF:BANDWIDTH=4500000,RESOLUTION=1920x1080
https://videos.example/playlist/1?type=video&rendition=1080p
#EXT-X-STREAM-INF:BANDWIDTH=2150000,RESOLUTION=1280x720
https://videos.example/playlist/1?type=video&rendition=720p
''';

StreamSearchContext _anime({int episode = 1}) => StreamSearchContext(
  tmdbId: '123',
  type: 'tv',
  title: 'Test Anime',
  isAnime: true,
  episode: episode,
  season: 1,
  mapping: AnimeMatch(anilistId: 7, kitsuId: '12', absoluteEpisode: episode),
);

void main() {
  late BuiltInAnimeSource source;
  late MockDio dio;
  late MockBuiltInAnimeLookup lookup;

  setUp(() {
    dio = MockDio();
    lookup = MockBuiltInAnimeLookup();
    source = BuiltInAnimeSource(
      dio,
      lookup,
      () async => ServerAddresses.fromRows([
        {'key': ServerAddress.animeSite.key, 'address': _site},
      ]),
      name: 'Anime Site',
    );
  });

  /// The site at [site] with [episodes] in its list for anime 999; each
  /// video's episode page leads to the video page `video-<id>`.
  void stubSite({
    String site = _site,
    List<Map<String, dynamic>> episodes = const [],
    String playlist = _masterPlaylist,
  }) {
    when(
      () => dio.get(
        '$site/api/anime/999/episodes',
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _answer({'episodes': episodes}));
    when(
      () => dio.get<String>(
        any(that: startsWith('$site/anime/999-test/')),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      final videoId = url.split('/').last;
      return _answer(
        _episodePage('https://videos.example/embed/$videoId?token=x&expires=1'),
      );
    });
    when(
      () => dio.get(
        any(that: startsWith('https://videos.example/embed/')),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      return _answer(_videoPage(Uri.parse(url).pathSegments.last));
    });
    when(
      () => dio.get(
        any(that: contains('.m3u8')),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _answer(playlist));
  }

  group('BuiltInAnimeSource', () {
    test('no address in the list: finds nothing (STR-08)', () async {
      source = BuiltInAnimeSource(
        dio,
        lookup,
        () async => ServerAddresses.empty,
        name: 'Anime Site',
      );

      final results = await source.search(_anime());

      expect(results, isEmpty);
      verifyZeroInteractions(dio);
      verifyZeroInteractions(lookup);
    });

    test(
      'one stream per language of the episode, from its video page',
      () async {
        final context = _anime();
        when(
          () => lookup.findEntries(context.mapping!),
        ).thenAnswer((_) async => _entryAt(_site));
        stubSite(
          episodes: [
            _episode(1, {'ita': 63456, 'jpn': 48279}),
          ],
        );

        final results = await source.search(context);

        expect(results, hasLength(2));
        final [dub, sub] = results;
        expect(dub.provider, 'Anime Site');
        expect(dub.title, 'Test Anime Ep.1 [ITA] [Anime Site]');
        expect(dub.metadata?.languages, ['ITA']);
        expect(sub.title, 'Test Anime Ep.1 [Anime Site]');
        expect(sub.metadata?.languages, ['JPN']);
        expect(
          dub.url,
          'https://videos.example/playlist/63456.m3u8'
          '?token=tok-63456&expires=123456&h=1',
        );
        expect(dub.metadata?.video.resolution, VideoResolution.r1080p);
        expect(
          dub.headers?['Referer'],
          'https://videos.example/embed/63456?token=x&expires=1',
        );

        // The episode list starts at the episode asked for.
        final query =
            verify(
                  () => dio.get(
                    '$_site/api/anime/999/episodes',
                    queryParameters: captureAny(named: 'queryParameters'),
                    options: any(named: 'options'),
                  ),
                ).captured.single
                as Map;
        expect(query['start'], 1);
        // The video page refuses a visit that doesn't come from the site.
        final videoPage =
            verify(
                  () => dio.get(
                    'https://videos.example/embed/63456?token=x&expires=1',
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as Options;
        expect(videoPage.headers?['Referer'], '$_site/');
      },
    );

    test('a video the site hides still plays', () async {
      final context = _anime();
      when(
        () => lookup.findEntries(context.mapping!),
      ).thenAnswer((_) async => _entryAt(_site));
      stubSite(
        episodes: [
          _episode(1, {'jpn': 50299}, hidden: true),
        ],
      );

      final results = await source.search(context);

      expect(results.single.url, contains('/playlist/50299.m3u8'));
    });

    test('a playlist that names its sound languages wins', () async {
      final context = _anime();
      when(
        () => lookup.findEntries(context.mapping!),
      ).thenAnswer((_) async => _entryAt(_site));
      stubSite(
        episodes: [
          _episode(1, {'jpn': 48279}),
        ],
        playlist: '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Italiano",LANGUAGE="it"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en"
''',
      );

      final results = await source.search(context);

      expect(results.single.metadata?.languages, containsAll(['ITA', 'ENG']));
      expect(
        results.single.metadata?.video.resolution,
        VideoResolution.unknown,
      );
    });

    test('a site that moved: the episodes come from its new address', () async {
      final context = _anime();
      when(
        () => lookup.findEntries(context.mapping!),
      ).thenAnswer((_) async => _entryAt('https://anime-new.example'));
      stubSite(
        site: 'https://anime-new.example',
        episodes: [
          _episode(1, {'ita': 63456}),
        ],
      );

      final results = await source.search(context);

      expect(results, hasLength(1));
      verify(
        () => dio.get<String>(
          'https://anime-new.example/anime/999-test/63456',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('search should return empty if context is not anime', () async {
      final context = StreamSearchContext(
        tmdbId: '123',
        type: 'movie',
        title: 'Test Movie',
        isAnime: false,
      );

      final results = await source.search(context);
      expect(results, isEmpty);
      verifyZeroInteractions(lookup);
    });

    test(
      'never plays another episode than the one asked for (REV-241)',
      () async {
        final context = _anime(episode: 3);
        when(
          () => lookup.findEntries(context.mapping!),
        ).thenAnswer((_) async => _entryAt(_site));
        stubSite(
          episodes: [
            _episode(2, {'ita': 1}),
            _episode(4, {'ita': 2}),
          ],
        );

        final results = await source.search(context);

        expect(results, isEmpty);
        verifyNever(
          () => dio.get<String>(
            any(that: startsWith('$_site/anime/')),
            options: any(named: 'options'),
          ),
        );
      },
    );
  });

  group('embedUrlOf', () {
    test("reads the video page's address from the page's data", () {
      expect(
        BuiltInAnimeSource.embedUrlOf(
          _episodePage(
            'https://videos.example/embed/1?token=a&expires=2&canPlayFHD=1',
          ),
        ),
        'https://videos.example/embed/1?token=a&expires=2&canPlayFHD=1',
      );
    });

    test('nothing on a page without it', () {
      expect(BuiltInAnimeSource.embedUrlOf(_episodePage(null)), isNull);
      expect(BuiltInAnimeSource.embedUrlOf('<html></html>'), isNull);
      expect(
        BuiltInAnimeSource.embedUrlOf('<div data-page="{not json"></div>'),
        isNull,
      );
    });
  });

  group('findEpisode', () {
    test('only the episode with that number', () {
      final episodes = [
        _episode(1, {'ita': 1}),
        _episode(2, {'ita': 2}),
      ];
      expect(BuiltInAnimeSource.findEpisode(episodes, 2)?['id'], 5002);
      expect(BuiltInAnimeSource.findEpisode(episodes, 3), isNull);
      expect(BuiltInAnimeSource.findEpisode('<html>', 1), isNull);
    });
  });
}
