import 'dart:typed_data';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/debrid/addon_link_check_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A made-up web: each address answers a status and headers.
class _Web implements HttpClientAdapter {
  final Map<String, (int, Map<String, List<String>>)> pages;
  final asked = <RequestOptions>[];
  _Web(this.pages);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options);
    final page = pages[options.uri.toString()];
    if (page == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no such host',
      );
    }
    return ResponseBody.fromString('x', page.$1, headers: page.$2);
  }

  @override
  void close({bool force = false}) {}
}

const _addonLink = 'https://addon.example/resolve/realdebrid/KEY/abc/1';

(int, Map<String, List<String>>) _redirectTo(String location) => (
  302,
  {
    'location': [location],
  },
);

(int, Map<String, List<String>>) _video(
  int size, {
  String type = 'video/mp4',
}) => (
  206,
  {
    Headers.contentTypeHeader: [type],
    Headers.contentLengthHeader: ['1'],
    'content-range': ['bytes 0-0/$size'],
  },
);

void main() {
  late _Web web;

  Future<DebridRefusal?> check(
    Map<String, (int, Map<String, List<String>>)> pages, {
    Map<String, String>? headers,
  }) {
    web = _Web(pages);
    return AddonLinkCheckService(
      Dio()..httpClientAdapter = web,
    ).errorVideoReason(_addonLink, headers: headers);
  }

  test('a real file on the debrid server plays', () async {
    final reason = await check({
      _addonLink: _redirectTo(
        'https://x1.download.real-debrid.com/d/ABC/ep.mkv',
      ),
      'https://x1.download.real-debrid.com/d/ABC/ep.mkv': _video(
        2400000000,
        type: 'video/x-matroska',
      ),
    });

    expect(reason, isNull);
  });

  test("Torrentio's downloading video: still downloading", () async {
    final reason = await check({
      _addonLink: _redirectTo('/videos/downloading_v3.mp4'),
      'https://addon.example/videos/downloading_v3.mp4': _video(118743),
    });

    expect(reason, DebridRefusal.downloading);
  });

  test("Torrentio's copyright video: refused", () async {
    final reason = await check({
      _addonLink: _redirectTo(
        'https://addon.example/videos/failed_infringement_v3.mp4',
      ),
      'https://addon.example/videos/failed_infringement_v3.mp4': _video(148959),
    });

    expect(reason, DebridRefusal.copyright);
  });

  test("MediaFusion's limit video, reached in two hops: a limit", () async {
    final reason = await check({
      _addonLink: _redirectTo('https://addon.example/playback/abc'),
      'https://addon.example/playback/abc': _redirectTo(
        '/static/exceptions/torrent_limit.mp4',
      ),
      'https://addon.example/static/exceptions/torrent_limit.mp4': _video(
        100260,
      ),
    });

    expect(reason, DebridRefusal.limit);
  });

  test('an unknown small video, range ignored: another reason', () async {
    final reason = await check({
      _addonLink: (
        200,
        {
          Headers.contentTypeHeader: ['video/mp4'],
          Headers.contentLengthHeader: ['130000'],
        },
      ),
    });

    expect(reason, DebridRefusal.other);
  });

  test('a small playlist is not a video: it plays', () async {
    final reason = await check({
      _addonLink: _video(2048, type: 'application/vnd.apple.mpegurl'),
    });

    expect(reason, isNull);
  });

  test('no size given: it plays as before', () async {
    final reason = await check({
      _addonLink: (
        200,
        {
          Headers.contentTypeHeader: ['video/mp4'],
        },
      ),
    });

    expect(reason, isNull);
  });

  test('no answer: it plays as before', () async {
    expect(await check({}), isNull);
  });

  test("asks one byte, with the add-on's own headers", () async {
    await check(
      {_addonLink: _video(2400000000)},
      headers: {'Referer': 'https://site.example/'},
    );

    final headers = web.asked.single.headers;
    expect(headers['Range'], 'bytes=0-0');
    expect(headers['Referer'], 'https://site.example/');
    expect(web.asked.single.followRedirects, isFalse);
  });
}
