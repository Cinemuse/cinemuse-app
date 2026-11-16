import 'package:cinemuse_app/features/video_player/application/handlers/livetv_picture_size_switcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pictureSizesFromTrackList', () {
    List<(int, String)> sizes(String json) => [
      for (final s in pictureSizesFromTrackList(json)) (s.height, s.trackId),
    ];

    test('the video sizes, biggest first; the sound is left out', () {
      // Rai 1, as mpv lists it (some fields left out).
      const json = '''[
        {"id": 1, "type": "audio", "lang": "ita", "hls-bitrate": 1365331},
        {"id": 5, "type": "video", "demux-h": 432, "hls-bitrate": 1365331},
        {"id": 1, "type": "video", "demux-h": 1080, "hls-bitrate": 5340630},
        {"id": 3, "type": "video", "demux-h": 720, "hls-bitrate": 2793078}
      ]''';

      expect(sizes(json), [(1080, '1'), (720, '3'), (432, '5')]);
    });

    test('two variants of one size: the one with more bits per second', () {
      // Sky's TV8 has two 480p.
      const json = '''[
        {"id": 1, "type": "video", "demux-h": 480, "hls-bitrate": 2072124},
        {"id": 2, "type": "video", "demux-h": 360, "hls-bitrate": 948212},
        {"id": 3, "type": "video", "demux-h": 480, "hls-bitrate": 3196037}
      ]''';

      expect(sizes(json), [(480, '3'), (360, '2')]);
    });

    test('a track without a size, or no tracks, gives no sizes', () {
      expect(sizes('[{"id": 1, "type": "video"}]'), isEmpty);
      expect(sizes('[]'), isEmpty);
    });
  });
}
