import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('YoutubeExplode download debugging', () async {
    final yt = YoutubeExplode();
    final client = HttpClient();

    try {
      const videoId = 'aqz-KE-bpKQ'; // Big Buck Bunny

      final manifest = await yt.videos.streams.getManifest(videoId);

      final audio = manifest.audioOnly;
      if (audio.isEmpty) {
        return;
      }

      final bestAudio = audio.withHighestBitrate();

      final request = await client.getUrl(bestAudio.url);

      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
      );

      final response = await request.close();

      if (response.statusCode == 200) {
        final file = File('debug_audio_manual_test.webm');
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.flush();
        await sink.close();
      }
    } catch (e) {
      // Ignore
    } finally {
      yt.close();
      client.close();
    }
  });
}
