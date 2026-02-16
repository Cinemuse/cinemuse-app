
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('YoutubeExplode download debugging', () async {
    print('Starting debug test...');
    final yt = YoutubeExplode();
    final client = HttpClient();

    try {
      const videoId = 'aqz-KE-bpKQ'; // Big Buck Bunny
      print('Fetching video metadata for $videoId...');
      
      final video = await yt.videos.get(videoId);
      print('Video Title: ${video.title}');

      print('Fetching manifest...');
      final manifest = await yt.videos.streams.getManifest(videoId);
      print('Manifest fetched successfully.');

      final audio = manifest.audioOnly;
      if (audio.isEmpty) {
        print('No audio streams found.');
        return;
      }
      
      final bestAudio = audio.withHighestBitrate();
      print('Best Audio Bitrate: ${bestAudio.bitrate}');
      print('Stream URL: ${bestAudio.url}');
      
      print('Starting manual download via HttpClient...');
      print('HttpClient created.');
      
      print('Calling getUrl...');
      final request = await client.getUrl(bestAudio.url);
      print('Request object created.');
      
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3');
      print('Headers set. Closing request...');
      
      final response = await request.close();
      print('Response received. Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('Opening file for writing...');
         final file = File('debug_audio_manual_test.webm');
         final sink = file.openWrite();
         print('Piping response to file...');
         await response.pipe(sink);
         await sink.flush();
         await sink.close();
         print('Manual download complete: ${file.lengthSync()} bytes');
      } else {
         print('Manual download failed with status ${response.statusCode}');
      }
      
    } catch (e) {
      print('Error occurred: $e');
    } finally {
      yt.close();
      client.close();
      print('Cleanup done.');
    }
  });
}
