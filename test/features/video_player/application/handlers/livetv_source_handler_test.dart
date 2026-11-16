import 'dart:async';
import 'dart:typed_data';

import 'package:cinemuse_app/features/live_tv/data/live_link_resolver.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/live_buffer_size.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockNativePlayer extends Mock implements NativePlayer {}

/// Answers every request with [status] and [body], and remembers the address.
class _SkyAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  String? asked;
  _SkyAdapter(this.status, this.body);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked = options.uri.toString();
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => registerFallbackValue(Media('https://fallback')));

  late _MockPlayer player;
  late _MockPlayerStream stream;

  setUp(() {
    player = _MockPlayer();
    stream = _MockPlayerStream();
    when(() => player.stream).thenReturn(stream);
    when(() => stream.buffering).thenAnswer((_) => const Stream.empty());
    when(() => stream.duration).thenAnswer((_) => const Stream.empty());
    when(() => stream.width).thenAnswer((_) => const Stream.empty());
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
  });

  Channel channel([String url = 'https://a/live.m3u8']) => Channel(
    lcn: 1,
    name: 'A',
    logo: '',
    links: [StreamLink(url: url)],
  );

  Map<String, String> openedHeaders() =>
      (verify(() => player.open(captureAny(), play: true)).captured.single
              as Media)
          .httpHeaders!;

  test(
    'a handler disposed during the URL lookup opens nothing (REV-146)',
    () async {
      final handler = LiveTvSourceHandler(player);
      // The lookup is awaited even for a plain URL, so the user's channel
      // switch (dispose) lands in the same gap a slow relinker leaves.
      final result = handler.initialize(channel(), const UserSettings());
      handler.dispose();

      expect(await result, isNull);
      verifyNever(() => player.open(any(), play: any(named: 'play')));
      verifyNever(() => stream.buffering);
    },
  );

  test('a live handler opens the stream', () async {
    final handler = LiveTvSourceHandler(player);
    addTearDown(handler.dispose);

    final result = await handler.initialize(channel(), const UserSettings());

    expect(result, isNotNull);
    verify(() => player.open(any(), play: true)).called(1);
  });

  test('a live HLS channel downloads each chunk in one go', () async {
    final native = _MockNativePlayer();
    when(() => native.setProperty(any(), any())).thenAnswer((_) async {});
    when(() => player.platform).thenReturn(native);
    final handler = LiveTvSourceHandler(player);
    addTearDown(handler.dispose);

    await handler.initialize(channel(), const UserSettings());

    final options =
        verify(
              () => native.setProperty('demuxer-lavf-o', captureAny()),
            ).captured.single
            as String;
    expect(options.split(','), contains('http_seekable=0'));
  });

  // Without `reconnect=1` FFmpeg ignores its other reconnect options, so a
  // dropped connection ended the stream (checked with ffmpeg on a test
  // server that cuts the connection).
  test('a dropped connection reconnects', () async {
    final native = _MockNativePlayer();
    when(() => native.setProperty(any(), any())).thenAnswer((_) async {});
    when(() => player.platform).thenReturn(native);
    final handler = LiveTvSourceHandler(player);
    addTearDown(handler.dispose);

    await handler.initialize(channel(), const UserSettings());

    final options =
        verify(
              () => native.setProperty('stream-lavf-o', captureAny()),
            ).captured.single
            as String;
    expect(
      options.split(','),
      containsAll(['reconnect=1', 'reconnect_streamed=1']),
    );
  });

  // mpv keeps `vid` for the next file: set before the open, every time.
  test('the stream opens on the picture size asked for', () async {
    final native = _MockNativePlayer();
    when(() => native.setProperty(any(), any())).thenAnswer((_) async {});
    when(() => player.platform).thenReturn(native);
    final handler = LiveTvSourceHandler(player);
    addTearDown(handler.dispose);

    await handler.initializeWithLink(
      channel(),
      channel().links.single,
      const UserSettings(),
      videoTrack: '5',
    );
    await handler.initialize(channel(), const UserSettings());

    verifyInOrder([
      () => native.setProperty('vid', '5'),
      () => player.open(any(), play: true),
      () => native.setProperty('vid', 'auto'),
      () => player.open(any(), play: true),
    ]);
  });

  group('a channel the playlist says to ask Sky for', () {
    Channel skyChannel() => Channel(
      lcn: 8,
      name: 'TV8',
      logo: '',
      links: [
        StreamLink(url: 'https://sky.example/getLivestream?id=7', ask: 'sky'),
      ],
    );

    String openedUrl() =>
        (verify(() => player.open(captureAny(), play: true)).captured.single
                as Media)
            .uri;

    test('plays the address Sky answers with', () async {
      final sky = _SkyAdapter(
        200,
        '{"streaming_url":"https://cdn.example/tv8/master.m3u8"}',
      );
      final handler = LiveTvSourceHandler(
        player,
        resolver: LiveLinkResolver(dio: Dio()..httpClientAdapter = sky),
      );
      addTearDown(handler.dispose);

      await handler.initialize(skyChannel(), const UserSettings());

      expect(sky.asked, 'https://sky.example/getLivestream?id=7');
      expect(openedUrl(), 'https://cdn.example/tv8/master.m3u8');
    });

    test('a Sky that refuses still opens the channel', () async {
      final handler = LiveTvSourceHandler(
        player,
        resolver: LiveLinkResolver(
          dio: Dio()..httpClientAdapter = _SkyAdapter(403, 'Forbidden'),
        ),
      );
      addTearDown(handler.dispose);

      final result = await handler.initialize(
        skyChannel(),
        const UserSettings(),
      );

      expect(result, isNotNull);
      expect(openedUrl(), 'https://sky.example/getLivestream?id=7');
    });
  });

  group('the playlist\'s own headers', () {
    test('are sent with the stream and win over the app\'s own', () async {
      final handler = LiveTvSourceHandler(player);
      addTearDown(handler.dispose);
      final link = StreamLink(
        url: 'https://a/live.m3u8',
        headers: const {'Referer': 'https://page.example/', 'User-Agent': 'X'},
      );

      await handler.initializeWithLink(
        Channel(lcn: 1, name: 'A', logo: '', links: [link]),
        link,
        const UserSettings(),
      );

      final headers = openedHeaders();
      expect(headers['Referer'], 'https://page.example/');
      expect(headers['User-Agent'], 'X');
    });

    test('a link without them sends only the app\'s own', () async {
      final handler = LiveTvSourceHandler(player);
      addTearDown(handler.dispose);

      await handler.initialize(channel(), const UserSettings());

      expect(openedHeaders().keys, unorderedEquals(['User-Agent', 'Accept']));
    });
  });

  // ".ts" inside a token used to make an HLS link look like a raw stream,
  // which skipped the HLS settings.
  test('an HLS link with ".ts" in its query is opened as HLS', () async {
    final native = _MockNativePlayer();
    when(() => native.setProperty(any(), any())).thenAnswer((_) async {});
    when(() => player.platform).thenReturn(native);
    final handler = LiveTvSourceHandler(player);
    addTearDown(handler.dispose);

    await handler.initialize(
      channel('https://a/live.m3u8?token=a.tsb'),
      const UserSettings(),
    );

    verify(() => native.setProperty('demuxer-lavf-o', any())).called(1);
  });

  group('the buffer', () {
    const mib = 1024 * 1024;
    late _MockNativePlayer native;

    setUp(() {
      native = _MockNativePlayer();
      when(() => native.setProperty(any(), any())).thenAnswer((_) async {});
      when(() => native.getProperty(any())).thenAnswer((_) async => '');
      when(() => player.platform).thenReturn(native);
    });

    List<String> setTo(String property) => verify(
      () => native.setProperty(property, captureAny()),
    ).captured.cast<String>();

    LiveTvSourceHandler handler({required int freeMemory, LiveDevice? device}) {
      final handler = LiveTvSourceHandler(
        player,
        readFreeMemory: () async => freeMemory,
        device: device ?? LiveDevice.computer,
      );
      addTearDown(handler.dispose);
      return handler;
    }

    // The Fire Stick had about 230 MB free and closed other apps with a
    // 256 MB buffer.
    test("opens with a TV's share, at most half the free memory", () async {
      await handler(
        freeMemory: 200 * mib,
        device: LiveDevice.tv,
      ).initialize(channel(), const UserSettings());

      expect(setTo('demuxer-max-bytes'), ['${75 * mib}']);
      expect(setTo('demuxer-max-back-bytes'), ['${25 * mib}']);
    });

    test(
      'shrinks to the rewind length once the channel says its rate',
      () async {
        when(() => stream.width).thenAnswer((_) => Stream.value(1920));
        when(
          () => native.getProperty('current-tracks/video/hls-bitrate'),
        ).thenAnswer((_) async => '5340630');

        await handler(
          freeMemory: 16 * 1024 * mib,
        ).initialize(channel(), const UserSettings(liveTvRewindMinutes: 2));
        await pumpEventQueue();

        final fitted = LiveBufferSize.forChannel(
          device: LiveDevice.computer,
          rewindMinutes: 2,
          freeMemoryBytes: 16 * 1024 * mib,
          bitsPerSecond: 5340630,
        );
        expect(setTo('demuxer-max-bytes'), [
          '${1536 * mib}',
          '${fitted.aheadBytes}',
        ]);
        expect(setTo('demuxer-max-back-bytes').last, '${fitted.rewindBytes}');
      },
    );

    test('a channel that never says its rate keeps its opening size', () async {
      when(() => stream.width).thenAnswer((_) => Stream.value(1920));

      await handler(
        freeMemory: 16 * 1024 * mib,
      ).initialize(channel(), const UserSettings());
      await pumpEventQueue();

      expect(setTo('demuxer-max-bytes'), ['${1536 * mib}']);
    });

    test('a channel changed before its rate came keeps the new size', () async {
      final width = StreamController<int?>();
      addTearDown(width.close);
      when(() => stream.width).thenAnswer((_) => width.stream);
      when(
        () => native.getProperty('current-tracks/video/hls-bitrate'),
      ).thenAnswer((_) async => '5340630');
      final first = handler(freeMemory: 16 * 1024 * mib);

      await first.initialize(channel(), const UserSettings());
      first.dispose();
      width.add(1920);
      await pumpEventQueue();

      expect(setTo('demuxer-max-bytes'), ['${1536 * mib}']);
    });
  });
}
