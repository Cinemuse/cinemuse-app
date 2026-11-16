import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_engine_configurator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockNativePlayer extends Mock implements NativePlayer {}

ResolvedStream _stream({required bool reconnects}) => ResolvedStream(
  url: 'https://host/film.m3u8',
  provider: 'Site',
  candidate: StreamCandidate(
    kind: StreamSourceKind.vod,
    title: 'Film',
    provider: 'Site',
    url: 'https://host/film.m3u8',
    reconnects: reconnects,
  ),
);

void main() {
  group('PlayerEngineConfigurator.tlsProperties', () {
    test('turns certificate checks on against the bundle file', () {
      expect(PlayerEngineConfigurator.tlsProperties(r'C:\data\cacert.pem'), {
        'tls-verify': 'yes',
        'tls-ca-file': r'C:\data\cacert.pem',
      });
    });
  });

  group('PlayerEngineConfigurator.hardwareDecoding', () {
    test('Android tries the chip copy mode before the processor', () {
      expect(
        PlayerEngineConfigurator.hardwareDecoding(
          isAndroid: true,
          isLinux: false,
        ),
        'mediacodec,mediacodec-copy',
      );
    });

    test('computers keep mpv\'s own pick', () {
      expect(
        PlayerEngineConfigurator.hardwareDecoding(
          isAndroid: false,
          isLinux: false,
        ),
        'auto-safe',
      );
      expect(
        PlayerEngineConfigurator.hardwareDecoding(
          isAndroid: false,
          isLinux: true,
        ),
        'auto',
      );
    });
  });

  group('PlayerEngineConfigurator.openStream', () {
    setUpAll(() => registerFallbackValue(Media('https://fallback')));

    late _MockPlayer player;
    late _MockNativePlayer native;
    late List<String> calls;

    setUp(() {
      player = _MockPlayer();
      native = _MockNativePlayer();
      calls = [];
      when(() => player.platform).thenReturn(native);
      when(() => native.setProperty(any(), any())).thenAnswer((i) async {
        calls.add('${i.positionalArguments[0]}=${i.positionalArguments[1]}');
      });
      when(() => player.open(any(), play: any(named: 'play'))).thenAnswer((
        _,
      ) async {
        calls.add('open');
      });
    });

    test('a source that turns reconnect off opens without it', () async {
      await PlayerEngineConfigurator.openStream(
        player,
        _stream(reconnects: false),
        play: true,
      );

      expect(calls, ['stream-lavf-o=', 'open']);
    });

    test('the next stream gets reconnect back before it opens', () async {
      await PlayerEngineConfigurator.openStream(
        player,
        _stream(reconnects: false),
        play: true,
      );
      await PlayerEngineConfigurator.openStream(
        player,
        _stream(reconnects: true),
        play: false,
      );

      expect(calls[2], startsWith('stream-lavf-o=reconnect=1,'));
      expect(calls.last, 'open');
      final opened =
          verify(() => player.open(captureAny(), play: false)).captured.single
              as Media;
      expect(opened.uri, 'https://host/film.m3u8');
    });

    test('a stream given a start opens there', () async {
      await PlayerEngineConfigurator.openStream(
        player,
        _stream(reconnects: true),
        play: true,
        start: const Duration(seconds: 2161),
      );

      final opened =
          verify(() => player.open(captureAny(), play: true)).captured.single
              as Media;
      expect(opened.start, const Duration(seconds: 2161));
    });
  });
}
