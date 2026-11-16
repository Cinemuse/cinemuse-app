import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/video_player/data/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// AudioTrack isn't exported by the package, but the service reads it.
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/videos/streams/models/audio_track.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _MockYoutubeExplode extends Mock implements YoutubeExplode {}

class _MockVideoClient extends Mock implements VideoClient {}

class _MockStreamClient extends Mock implements StreamClient {}

class _MockVideoOnly extends Mock implements VideoOnlyStreamInfo {}

class _MockMuxed extends Mock implements MuxedStreamInfo {}

class _MockAudioOnly extends Mock implements AudioOnlyStreamInfo {}

VideoOnlyStreamInfo _videoOnly(
  VideoQuality quality,
  String url, {
  required int height,
}) {
  final s = _MockVideoOnly();
  when(() => s.videoQuality).thenReturn(quality);
  when(
    () => s.videoResolution,
  ).thenReturn(VideoResolution(height * 16 ~/ 9, height));
  when(() => s.url).thenReturn(Uri.parse(url));
  when(() => s.container).thenReturn(StreamContainer.mp4);
  return s;
}

MuxedStreamInfo _muxed(VideoQuality quality, String url) {
  final s = _MockMuxed();
  when(() => s.videoQuality).thenReturn(quality);
  when(() => s.videoResolution).thenReturn(const VideoResolution(640, 360));
  when(() => s.url).thenReturn(Uri.parse(url));
  when(() => s.container).thenReturn(StreamContainer.mp4);
  return s;
}

AudioOnlyStreamInfo _audio(int bitrate, String url, {bool dubbed = false}) {
  final s = _MockAudioOnly();
  when(() => s.bitrate).thenReturn(Bitrate(bitrate));
  when(() => s.url).thenReturn(Uri.parse(url));
  when(() => s.audioTrack).thenReturn(
    dubbed
        ? const AudioTrack(
            displayName: 'Italian',
            id: 'it',
            audioIsDefault: false,
          )
        : null,
  );
  return s;
}

void main() {
  late _MockStreamClient streams;
  late YoutubeService service;

  setUp(() {
    final yt = _MockYoutubeExplode();
    final videos = _MockVideoClient();
    streams = _MockStreamClient();
    when(() => yt.videos).thenReturn(videos);
    when(() => videos.streamsClient).thenReturn(streams);
    service = YoutubeService(client: yt);
  });

  void manifestReturns(List<StreamInfo> infos) {
    when(
      () => streams.getManifest(any(), ytClients: any(named: 'ytClients')),
    ).thenAnswer((_) async => StreamManifest(infos));
  }

  /// The clients of every request made, in order.
  List<List<YoutubeApiClient>> askedClients() => verify(
    () => streams.getManifest('abc', ytClients: captureAny(named: 'ytClients')),
  ).captured.cast<List<YoutubeApiClient>>();

  String clientName(YoutubeApiClient client) =>
      (client.payload['context'] as Map)['client']['clientName'] as String;

  test('asks the Android way only, with the extra setting', () async {
    manifestReturns([_muxed(VideoQuality.medium360, 'https://m/360')]);

    await service.getStreamQualities('abc');

    final asked = askedClients();
    expect(asked, hasLength(1));
    expect(asked.single, hasLength(1));
    expect(
      clientName(asked.single.single),
      clientName(YoutubeApiClient.androidSdkless),
    );
    expect(asked.single.single.payload['params'], '2AMB');
  });

  test(
    'asks the iPhone way, with the extra setting, when Android fails',
    () async {
      var calls = 0;
      when(
        () => streams.getManifest(any(), ytClients: any(named: 'ytClients')),
      ).thenAnswer((_) async {
        if (calls++ == 0) throw VideoUnplayableException('Sign in to confirm');
        return StreamManifest([
          _muxed(VideoQuality.medium360, 'https://m/360'),
        ]);
      });

      final qualities = await service.getStreamQualities('abc');

      expect(qualities.single.url, 'https://m/360');
      final asked = askedClients();
      expect(asked, hasLength(2));
      expect(clientName(asked[1].single), clientName(YoutubeApiClient.ios));
      expect(asked[1].single.payload['params'], '2AMB');
    },
  );

  test('video-only qualities carry the best audio link, best first', () async {
    manifestReturns([
      _videoOnly(VideoQuality.high720, 'https://v/720', height: 720),
      _videoOnly(VideoQuality.high1080, 'https://v/1080', height: 1080),
      _audio(50000, 'https://a/low'),
      _audio(130000, 'https://a/high'),
      _muxed(VideoQuality.medium360, 'https://m/360'),
    ]);

    final qualities = await service.getStreamQualities('abc');

    expect(qualities.map((q) => q.title), ['1080p HD', '720p HD', '360p']);
    expect(qualities[0].needsAudio, isTrue);
    expect(qualities[0].audioUrl, 'https://a/high');
    expect(qualities[2].needsAudio, isFalse);
    expect(qualities[2].audioUrl, isNull);
  });

  test('the 360p stream with sound replaces the silent 360p one', () async {
    manifestReturns([
      _videoOnly(VideoQuality.high1080, 'https://v/1080', height: 1080),
      _videoOnly(VideoQuality.medium360, 'https://v/360', height: 360),
      _audio(130000, 'https://a/high'),
      _muxed(VideoQuality.medium360, 'https://m/360'),
    ]);

    final qualities = await service.getStreamQualities('abc');

    expect(qualities.map((q) => q.title), ['1080p HD', '360p']);
    expect(qualities[1].url, 'https://m/360');
    expect(qualities[1].needsAudio, isFalse);
  });

  test('240p and 144p each keep their own line', () async {
    // YouTube's label says "144" for both of them.
    manifestReturns([
      _videoOnly(VideoQuality.low144, 'https://v/240', height: 240),
      _videoOnly(VideoQuality.low144, 'https://v/144', height: 144),
      _audio(130000, 'https://a/high'),
    ]);

    final qualities = await service.getStreamQualities('abc');

    expect(qualities.map((q) => q.title), ['240p SD', '144p SD']);
    expect(qualities.map((q) => q.url), ['https://v/240', 'https://v/144']);
  });

  test('prefers the original audio track over a louder dubbed one', () async {
    manifestReturns([
      _videoOnly(VideoQuality.high1080, 'https://v/1080', height: 1080),
      _audio(200000, 'https://a/dubbed', dubbed: true),
      _audio(130000, 'https://a/original'),
    ]);

    final qualities = await service.getStreamQualities('abc');

    expect(qualities.single.audioUrl, 'https://a/original');
  });

  test(
    'with no audio-only stream, keeps the muxed ones instead of failing',
    () async {
      manifestReturns([
        _videoOnly(VideoQuality.high1080, 'https://v/1080', height: 1080),
        _muxed(VideoQuality.medium360, 'https://m/360'),
      ]);

      final qualities = await service.getStreamQualities('abc');

      expect(qualities.single.url, 'https://m/360');
    },
  );

  test('every way refused: a StreamingFailure with the cause', () async {
    final refused = VideoUnplayableException('Sign in to confirm');
    when(
      () => streams.getManifest(any(), ytClients: any(named: 'ytClients')),
    ).thenThrow(refused);

    await expectLater(
      service.getStreamQualities('abc'),
      throwsA(isA<StreamingFailure>().having((f) => f.cause, 'cause', refused)),
    );
  });

  test('a video with no playable streams throws a StreamingFailure', () async {
    manifestReturns([]);

    await expectLater(
      service.getStreamQualities('abc'),
      throwsA(isA<StreamingFailure>()),
    );
  });
}
