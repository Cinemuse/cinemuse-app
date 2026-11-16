import 'dart:typed_data';

import 'package:cinemuse_app/features/live_tv/data/live_link_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [status], [body] and [headers], and remembers
/// the addresses asked.
class _Adapter implements HttpClientAdapter {
  final int status;
  final String body;
  final Map<String, List<String>> headers;
  final asked = <String>[];
  _Adapter(this.status, this.body, {this.headers = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.uri.toString());
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  LiveLinkResolver resolver(_Adapter adapter) =>
      LiveLinkResolver(dio: Dio()..httpClientAdapter = adapter);

  group('a channel the playlist says to ask Rai for', () {
    // The built-in playlist labels Rai's channels; the label used to be
    // ignored, and Rai was asked only when its address was in the link.
    test('is asked by the label, whatever its address', () async {
      final rai = _Adapter(200, '{"video":["https://cdn.example/rai1.m3u8"]}');

      final url = await resolver(rai).resolve('https://rai.example/1', 'rai');

      expect(rai.asked, ['https://rai.example/1']);
      expect(url, 'https://cdn.example/rai1.m3u8');
    });

    test('a Rai that has no stream leaves the link as it is', () async {
      final rai = _Adapter(200, '{"video":["https://x/video_no_available"]}');

      final url = await resolver(rai).resolve('https://rai.example/1', 'rai');

      expect(url, 'https://rai.example/1');
    });
  });

  test('Rai\'s lookup address is asked even without the label', () async {
    final rai = _Adapter(200, '{"video":["https://cdn.example/rai2.m3u8"]}');

    final url = await resolver(
      rai,
    ).resolve('https://mediapolis.rai.it/relinker/relinkerServlet.htm', null);

    expect(url, 'https://cdn.example/rai2.m3u8');
  });

  test('Rai\'s address inside another link\'s query asks no one', () async {
    final adapter = _Adapter(200, '{}');
    const link = 'https://cdn.example/x.m3u8?ref=mediapolis.rai.it/relinker';

    expect(await resolver(adapter).resolve(link, null), link);
    expect(adapter.asked, isEmpty);
  });

  test('an Xtream link plays where its server redirects', () async {
    final server = _Adapter(
      302,
      '',
      headers: {
        'location': ['http://edge.example/1.ts?token=t'],
      },
    );

    final url = await resolver(
      server,
    ).resolve('http://xtream.example:8080/live/u/p/1.ts', null);

    expect(url, 'http://edge.example/1.ts?token=t');
  });

  test('a Sky that refuses leaves the link as it is', () async {
    final url = await resolver(
      _Adapter(403, 'Forbidden'),
    ).resolve('https://sky.example/getLivestream?id=7', 'sky');

    expect(url, 'https://sky.example/getLivestream?id=7');
  });
}
