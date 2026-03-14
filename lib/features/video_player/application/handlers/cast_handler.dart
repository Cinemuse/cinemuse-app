import 'dart:async';
import 'package:cast/cast.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';

class CastHandler {
  CastSession? _castSession;
  final Ref _ref;
  final UnifiedStreamResolver _resolver;
  int _requestId = 1;
  int? _mediaSessionId;
  String? _appSessionId;
  final String _appId = 'CC1AD845'; // Default Media Receiver
  Timer? _statusTimer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  void Function(bool isPlaying, Duration position, Duration duration)? onStatusSync;

  CastHandler(this._ref, this._resolver);

  bool get isCasting => _castSession != null;

  Future<void> startCasting(
    CastDevice device, 
    StreamCandidate candidate, 
    String title, 
    Duration currentPosition,
    Function(ResolvedStream) onStreamResolved, {
    int? season,
    int? episode,
    int? absoluteEpisode,
  }) async {
    try {
      _castSession = await CastSessionManager().startSession(device);
      _mediaSessionId = null; // Reset for new session
      
      _castSession!.messageStream.listen((message) {
        // Unnecessary type check removed (message is always Map)
        
        if (message['type'] == 'MEDIA_STATUS') {
          debugPrint('CastHandler: Received MEDIA_STATUS: $message');
          final statusList = message['status'] as List?;
          if (statusList != null && statusList.isNotEmpty) {
            final Map<String, dynamic> status = statusList[0];
            
            // 1. Update Media Session ID
            final mediaSessionId = status['mediaSessionId'];
            if (mediaSessionId != null && _mediaSessionId != mediaSessionId) {
              _mediaSessionId = mediaSessionId;
              debugPrint('CastHandler: Media Session ID established/updated: $_mediaSessionId');
            }

            // 2. Update Playback State
            final playerState = status['playerState'];
            if (playerState != null) {
              _isPlaying = playerState == 'PLAYING' || playerState == 'BUFFERING';
            }

            // 3. Update Position
            final currentTime = status['currentTime'];
            if (currentTime != null) {
              _currentPosition = Duration(seconds: (currentTime as num).toInt());
            }

            // 4. Update Duration
            final media = status['media'];
            if (media != null && media['duration'] != null) {
              _duration = Duration(seconds: (media['duration'] as num).toInt());
            }

            // 5. Notify Controller
            onStatusSync?.call(_isPlaying, _currentPosition, _duration);
          }
        } else if (message['type'] == 'RECEIVER_STATUS') {
          debugPrint('CastHandler: Received RECEIVER_STATUS: $message');
          final status = message['status'];
          if (status != null && status['applications'] != null) {
            final apps = status['applications'] as List;
            for (final app in apps) {
              if (app['appId'] == _appId) {
                _appSessionId = app['sessionId'];
                debugPrint('CastHandler: Captured Application Session ID: $_appSessionId');
              }
            }
          }
        }
      });

      // 1. Launch the default media receiver
      debugPrint('CastHandler: Launching Default Media Receiver (CC1AD845)');
      _castSession!.sendMessage('urn:x-cast:com.google.cast.receiver', {
        'type': 'LAUNCH',
        'appId': _appId,
        'requestId': _requestId++,
      });

      // 2. Wait for the receiver app to start
      await Future.delayed(const Duration(milliseconds: 2000));

      // 3. Attempt to resolve the stream
      final resolvedStream = await _resolver.resolveStream(
        candidate,
        season: season,
        episode: episode,
      );

      if (resolvedStream == null) {
        throw Exception("No castable URL found");
      }

      final urlToCasting = resolvedStream.url;
      onStreamResolved(resolvedStream);

      // Determine contentType with Sniffing
      debugPrint('CastHandler: Sniffing MIME type for $urlToCasting');
      String? sniffedType = await _sniffMimeType(urlToCasting);
      final contentType = _guessMimeType(urlToCasting, sniffedType ?? resolvedStream.mimeType);

      // Metadata type: 1 for Movie, 2 for TV Show, 0 for Generic
      int metadataType = 0;
      if (season != null || episode != null) {
        metadataType = 2; // TV Show
      } else if (candidate.provider != 'YouTube') {
        metadataType = 1; // Movie
      }

      final Map<String, dynamic> mediaMetadata = {
        'metadataType': metadataType,
        'title': title,
      };

      if (metadataType == 2) {
        if (season != null) mediaMetadata['season'] = season;
        if (episode != null) mediaMetadata['episode'] = episode;
      }

      debugPrint('CastHandler: Sending LOAD command for $urlToCasting ($contentType)');

      _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': currentPosition.inSeconds,
        'requestId': _requestId++,
        'media': {
          'contentId': urlToCasting,
          'contentType': contentType,
          'streamType': 'BUFFERED',
          'metadata': mediaMetadata,
        },
      });

      debugPrint('CastHandler: Casting started to ${device.name}');

      // 4. Proactively request status to confirm session ID if not received yet
      _requestStatus();
      
      // 5. Start Polling for status updates (every 5 seconds)
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _requestStatus());
    } catch (e) {
      debugPrint('CastHandler: Error starting cast: $e');
      stopCasting();
      rethrow;
    }
  }

  void pause() {
    if (_castSession == null || _mediaSessionId == null) return;
    debugPrint('CastHandler: Pausing playback');
    _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'PAUSE',
      'mediaSessionId': _mediaSessionId,
      'requestId': _requestId++,
    });
  }

  void play() {
    if (_castSession == null || _mediaSessionId == null) return;
    debugPrint('CastHandler: Resuming playback');
    _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'PLAY',
      'mediaSessionId': _mediaSessionId,
      'requestId': _requestId++,
    });
  }

  void seek(Duration position) {
    if (_castSession == null || _mediaSessionId == null) return;
    debugPrint('CastHandler: Seeking to ${position.inSeconds}s');
    _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'SEEK',
      'mediaSessionId': _mediaSessionId,
      'currentTime': position.inSeconds,
      'requestId': _requestId++,
    });
  }

  Future<void> stopCasting() async {
    _statusTimer?.cancel();
    _statusTimer = null;

    if (_castSession != null) {
      debugPrint('CastHandler: Stopping media and application session');
      try {
        // 1. Try to stop media playback context
        if (_mediaSessionId != null) {
          _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
            'type': 'STOP',
            'mediaSessionId': _mediaSessionId,
            'requestId': _requestId++,
          });
        }

        // 2. Tell the receiver to stop the application entirely
        if (_appSessionId != null) {
          _castSession!.sendMessage('urn:x-cast:com.google.cast.receiver', {
            'type': 'STOP',
            'sessionId': _appSessionId,
            'requestId': _requestId++,
          });
        }

        // Short delay to let messages flush before nulling the session
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        debugPrint('CastHandler: Error sending stop commands: $e');
      }
    }
    
    debugPrint('CastHandler: Disconnecting session and notifying exit');
    _castSession = null;
    _mediaSessionId = null;
    _appSessionId = null;
    _requestId = 1;
    _isPlaying = false;
    _currentPosition = Duration.zero;
    _duration = Duration.zero;
    
    // Final notify of state change
    onStatusSync?.call(false, Duration.zero, Duration.zero);
  }

  void _requestStatus() {
    if (_castSession == null) return;
    
    // Request overall media status
    _castSession!.sendMessage('urn:x-cast:com.google.cast.media', {
      'type': 'GET_STATUS',
      'requestId': _requestId++,
    });
  }

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get duration => _duration;

  String _guessMimeType(String url, String? providedMime) {
    if (providedMime != null && providedMime != 'video/mp4' && providedMime.isNotEmpty) {
      return providedMime;
    }

    final lowerUrl = url.toLowerCase();
    
    // Check for HLS
    if (lowerUrl.contains('.m3u8') || 
        lowerUrl.contains('protocol=hls') || 
        lowerUrl.contains('.hls') ||
        lowerUrl.contains('/m3u8') ||
        lowerUrl.contains('m3u8')) {
      return 'application/x-mpegURL';
    }

    // Check for Matroska (MKV)
    if (lowerUrl.contains('.mkv') || lowerUrl.contains('container=mkv')) {
      return 'video/x-matroska';
    }

    // Check for MP4
    if (lowerUrl.contains('.mp4') || lowerUrl.contains('container=mp4')) {
      return 'video/mp4';
    }

    // Check for MediaFusion/Stremio direct playback patterns that might be MP4
    if (lowerUrl.contains('/playback/') && lowerUrl.endsWith('/1')) {
      // These are often direct streams, try mp4 as fallback if no extension
      return providedMime ?? 'video/mp4';
    }

    // Check for WebM
    if (lowerUrl.contains('.webm') || lowerUrl.contains('container=webm')) {
      return 'video/webm';
    }

    // Fallback
    return providedMime ?? 'video/mp4';
  }

  Future<String?> _sniffMimeType(String url) async {
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      
      final contentType = response.headers.value('content-type');
      if (contentType != null) {
        debugPrint('CastHandler: Sniffed Content-Type: $contentType');
        // Clean up charset etc (video/mp4; charset=UTF-8 -> video/mp4)
        return contentType.split(';').first.trim();
      }
    } catch (e) {
      debugPrint('CastHandler: Warning: MIME sniffing failed: $e');
    }
    return null;
  }
  void dispose() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _castSession = null;
  }
}

