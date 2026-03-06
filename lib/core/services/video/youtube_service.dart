import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final youtubeServiceProvider = Provider((ref) => YoutubeService());

class YoutubeService {
  final _yt = YoutubeExplode();

  // Store the last manifest's audio StreamInfo so we can download it
  // using the library's authenticated client later.
  AudioOnlyStreamInfo? _bestAudioStreamInfo;

  /// Returns the best audio StreamInfo from the last getStreamQualities() call.
  AudioOnlyStreamInfo? get bestAudioStreamInfo => _bestAudioStreamInfo;

  Future<List<Map<String, dynamic>>> getStreamQualities(String videoId) async {
    try {
      // Use AndroidVR first as iOS might be 403-ing in some regions
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final streams = <Map<String, dynamic>>[];

      // 1. Try HLS Manifest (Master m3u8) - Most stable for HD
      if (manifest.hls.isNotEmpty) {
        final hlsUrl = manifest.hls.first.url.toString();
        print('YT-DEBUG: Found HLS Manifest: $hlsUrl');
        streams.add({
          'title': 'High Definition (Auto)',
          'url': hlsUrl,
          'quality': 'hls',
          'res': 1080,
          'container': 'm3u8',
          'tag': 'youtube',
          'isHls': true,
        });
      } else {
        print('YT-DEBUG: No HLS Manifest found.');
      }

      // 2. Add Video-Only Streams (1080p, 1440p, 2160p etc.)
      final bestAudio = manifest.audioOnly.withHighestBitrate();
      _bestAudioStreamInfo = bestAudio;
      print('YT-DEBUG: Best Audio Bitrate: ${bestAudio.bitrate}');
      
      for (var s in manifest.videoOnly) {
        final qLabel = s.videoQuality.toString().split('.').last;
        final res = int.tryParse(qLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final label = '${res}p ${res >= 720 ? "(HD)" : "(SD)"}';
        
        final existingIdx = streams.indexWhere((e) => e['res'] == res && e['isHls'] != true);
        
        if (existingIdx == -1) {
          print('YT-DEBUG: Adding Video-Only Stream: $label');
          streams.add({
            'title': label,
            'url': s.url.toString(),
            'audioUrl': bestAudio.url.toString(),
            'quality': qLabel,
            'res': res,
            'container': s.container.name,
            'tag': 'youtube',
            'isHls': false,
            'needsAudio': true, // Flag: this stream needs a separate audio track
          });
        }
      }

      // 3. Add Muxed Streams (Reliable fallback for SD)
      for (var s in manifest.muxed) {
        final qLabel = s.videoQuality.toString().split('.').last;
        final res = int.tryParse(qLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        
        if (!streams.any((e) => e['res'] == res)) {
           print('YT-DEBUG: Adding Muxed Stream: ${res}p Standard');
           streams.add({
            'title': '${res}p Standard',
            'url': s.url.toString(),
            'quality': qLabel,
            'res': res,
            'container': s.container.name,
            'tag': 'youtube',
            'isHls': false,
            'needsAudio': false,
          });
        }
      }
      
      print('YT-DEBUG: Total streams found: ${streams.length}');
      streams.sort((a, b) {
        if (a['isHls'] == true) return -1;
        if (b['isHls'] == true) return 1;
        return (b['res'] as int) - (a['res'] as int);
      });

      return streams;
    } catch (e) {
      print('Error extracting YouTube streams: $e');
      return [];
    }
  }

  /// Downloads the best audio stream to a local temp file using the
  /// library's authenticated HTTP client. Returns the file path.
  Future<String> downloadAudioToFile(String tempFilePath) async {
    if (_bestAudioStreamInfo == null) {
      throw Exception('No audio stream info available. Call getStreamQualities() first.');
    }
    
    print('YT-DEBUG: Downloading audio via youtube_explode stream client...');
    print('YT-DEBUG: Audio bitrate: ${_bestAudioStreamInfo!.bitrate}, size: ${_bestAudioStreamInfo!.size}');
    
    final file = File(tempFilePath);
    final sink = file.openWrite();
    
    try {
      final audioStream = _yt.videos.streamsClient.get(_bestAudioStreamInfo!);
      int totalBytes = 0;
      int lastLoggedKB = 0;
      
      await for (final chunk in audioStream) {
        sink.add(chunk);
        totalBytes += chunk.length;
        final currentKB = totalBytes ~/ 1024;
        if (currentKB - lastLoggedKB >= 250) {
          print('YT-DEBUG: Audio download progress: ${currentKB}KB / ${_bestAudioStreamInfo!.size}');
          lastLoggedKB = currentKB;
        }
      }
      
      await sink.flush();
      await sink.close();
      print('YT-DEBUG: Audio download complete: $totalBytes bytes -> $tempFilePath');
      return tempFilePath;
    } catch (e) {
      await sink.close();
      try { await file.delete(); } catch (_) {}
      print('YT-DEBUG: Audio download FAILED: $e');
      rethrow;
    }
  }



  void dispose() {
    _yt.close();
  }
}
