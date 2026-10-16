import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_source_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

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
    when(
      () => player.open(any(), play: any(named: 'play')),
    ).thenAnswer((_) async {});
  });

  Channel channel() => Channel(
    lcn: 1,
    name: 'A',
    logo: '',
    links: [StreamLink(url: 'https://a/live.m3u8')],
  );

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
}
