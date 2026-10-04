import 'dart:developer' as developer;
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final youtubeServiceProvider = Provider((ref) => YoutubeService());

/// Strongly-typed domain model representing an available YouTube stream quality.
class YouTubeStreamQuality {
  final String title;
  final String url;
  final String quality;
  final int res;
  final String container;
  final String tag;
  final bool isHls;
  final bool needsAudio;
  final String? audioUrl;

  const YouTubeStreamQuality({
    required this.title,
    required this.url,
    required this.quality,
    required this.res,
    required this.container,
    required this.tag,
    this.isHls = false,
    this.needsAudio = false,
    this.audioUrl,
  });
}

class YoutubeService {
  final _yt = YoutubeExplode();

  // Store the last manifest's audio StreamInfo so we can download it
  // using the library's authenticated client later.
  AudioOnlyStreamInfo? _bestAudioStreamInfo;

  /// Returns the best audio StreamInfo from the last getStreamQualities() call.
  AudioOnlyStreamInfo? get bestAudioStreamInfo => _bestAudioStreamInfo;

  Future<List<YouTubeStreamQuality>> getStreamQualities(String videoId) async {
    try {
      // Use AndroidVR first as iOS might be 403-ing in some regions
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final streams = <YouTubeStreamQuality>[];

      // 1. Try HLS Manifest (Master m3u8) - Most stable for HD
      if (manifest.hls.isNotEmpty) {
        final hlsUrl = manifest.hls.first.url.toString();
        developer.log('Found HLS Manifest: $hlsUrl', name: 'YoutubeService');
        streams.add(
          YouTubeStreamQuality(
            title: 'High Definition (Auto)',
            url: hlsUrl,
            quality: 'hls',
            res: 1080,
            container: 'm3u8',
            tag: 'youtube',
            isHls: true,
          ),
        );
      } else {
        developer.log('No HLS Manifest found.', name: 'YoutubeService');
      }

      // 2. Add Video-Only Streams (1080p, 1440p, 2160p etc.)
      final bestAudio = manifest.audioOnly.withHighestBitrate();
      _bestAudioStreamInfo = bestAudio;
      developer.log(
        'Best Audio Bitrate: ${bestAudio.bitrate}',
        name: 'YoutubeService',
      );

      for (var s in manifest.videoOnly) {
        final qLabel = s.videoQuality.toString().split('.').last;
        final res = int.tryParse(qLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final label = '${res}p ${res >= 720 ? "(HD)" : "(SD)"}';

        final existingIdx = streams.indexWhere(
          (e) => e.res == res && !e.isHls,
        );

        if (existingIdx == -1) {
          developer.log(
            'Adding Video-Only Stream: $label',
            name: 'YoutubeService',
          );
          streams.add(
            YouTubeStreamQuality(
              title: label,
              url: s.url.toString(),
              audioUrl: bestAudio.url.toString(),
              quality: qLabel,
              res: res,
              container: s.container.name,
              tag: 'youtube',
              isHls: false,
              needsAudio: true,
            ),
          );
        }
      }

      // 3. Add Muxed Streams (Reliable fallback for SD)
      for (var s in manifest.muxed) {
        final qLabel = s.videoQuality.toString().split('.').last;
        final res = int.tryParse(qLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        if (!streams.any((e) => e.res == res)) {
          developer.log(
            'Adding Muxed Stream: ${res}p Standard',
            name: 'YoutubeService',
          );
          streams.add(
            YouTubeStreamQuality(
              title: '${res}p Standard',
              url: s.url.toString(),
              quality: qLabel,
              res: res,
              container: s.container.name,
              tag: 'youtube',
              isHls: false,
              needsAudio: false,
            ),
          );
        }
      }

      developer.log(
        'Total streams found: ${streams.length}',
        name: 'YoutubeService',
      );
      streams.sort((a, b) {
        if (a.isHls) return -1;
        if (b.isHls) return 1;
        return b.res - a.res;
      });

      return streams;
    } catch (e, st) {
      developer.log(
        'Error extracting YouTube streams: $e',
        name: 'YoutubeService',
        error: e,
        stackTrace: st,
        level: 900,
      );
      return [];
    }
  }

  /// Downloads the best audio stream to a local temp file using the
  /// library's authenticated HTTP client. Returns the file path.
  Future<String> downloadAudioToFile(String tempFilePath) async {
    if (_bestAudioStreamInfo == null) {
      throw Exception(
        'No audio stream info available. Call getStreamQualities() first.',
      );
    }

    developer.log(
      'Downloading audio via youtube_explode stream client. Bitrate: ${_bestAudioStreamInfo!.bitrate}, size: ${_bestAudioStreamInfo!.size}',
      name: 'YoutubeService',
    );

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
          developer.log(
            'Audio download progress: ${currentKB}KB / ${_bestAudioStreamInfo!.size}',
            name: 'YoutubeService',
          );
          lastLoggedKB = currentKB;
        }
      }

      await sink.flush();
      await sink.close();
      developer.log(
        'Audio download complete: $totalBytes bytes -> $tempFilePath',
        name: 'YoutubeService',
      );
      return tempFilePath;
    } catch (e, st) {
      await sink.close();
      try {
        await file.delete();
      } catch (deleteError, deleteStack) {
        developer.log(
          'Failed to clean up temporary audio file after download error',
          name: 'YoutubeService',
          error: deleteError,
          stackTrace: deleteStack,
        );
      }
      developer.log(
        'Audio download FAILED: $e',
        name: 'YoutubeService',
        error: e,
        stackTrace: st,
        level: 900,
      );
      rethrow;
    }
  }

  void dispose() {
    _yt.close();
  }
}
