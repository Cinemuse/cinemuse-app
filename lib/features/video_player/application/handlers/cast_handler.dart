import 'dart:async';
import 'package:cast/cast.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/utils/mime_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/cast_constants.dart';

class CastHandler {
  CastSession? _castSession;
  final Ref _ref;
  final UnifiedStreamResolver _resolver;
  int _requestId = 1;
  int? _mediaSessionId;
  String? _appSessionId;
  Completer<void>? _appLaunchCompleter;
  Timer? _statusTimer;
  Timer? _heartbeatTimer;
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
    String? detectedMimeType,
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
              if (app['appId'] == CastConstants.defaultAppId) {
                _appSessionId = app['sessionId'];
                debugPrint('CastHandler: Captured Application Session ID: $_appSessionId');
                
                // Resolve the launch completer if it's waiting
                if (_appLaunchCompleter != null && !_appLaunchCompleter!.isCompleted) {
                  _appLaunchCompleter!.complete();
                }
              }
            }
          }
        }
      });

      // 1. Launch the default media receiver
      debugPrint('CastHandler: Launching Default Media Receiver (${CastConstants.defaultAppId})');
      _appLaunchCompleter = Completer<void>();
      
      _castSession!.sendMessage(CastConstants.nsReceiver, {
        'type': 'LAUNCH',
        'appId': CastConstants.defaultAppId,
        'requestId': _requestId++,
      });

      // 2. Wait for the receiver app to start (max 10 seconds)
      await _appLaunchCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('CastHandler: Warning: App launch timeout, proceeding anyway...'),
      );

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

      // Determine contentType: Engine Probed > HTTP Sniffing > URL Resolver
      debugPrint('CastHandler: Resolving MIME type for $urlToCasting');
      
      String contentType;

      if (detectedMimeType != null) {
        debugPrint('CastHandler: Using Engine-detected MIME: $detectedMimeType');
        contentType = detectedMimeType;
      } else {
        String? sniffedType = await _sniffMimeType(urlToCasting);
        contentType = MimeResolver.resolve(urlToCasting, sniffedType ?? resolvedStream.mimeType);
        debugPrint('CastHandler: Final resolved MIME: $contentType (Sniffed: $sniffedType, Resolution: ${resolvedStream.mimeType})');
      }

      // 4. Send CONNECT to the application namespace
      _castSession!.sendMessage(CastConstants.nsConnection, {'type': 'CONNECT'});
      
      // 5. Start Heartbeat
      _startHeartbeat();
    

      // Metadata types: Movie, TV Show, or Generic
      int metadataType = CastConstants.metadataGeneric;
      if (season != null || episode != null) {
        metadataType = CastConstants.metadataTvShow;
      } else if (candidate.provider != 'YouTube') {
        metadataType = CastConstants.metadataMovie;
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

      _castSession!.sendMessage(CastConstants.nsMedia, {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': currentPosition.inSeconds,
        'requestId': _requestId++,
        'media': {
          'contentId': urlToCasting,
          'contentType': contentType,
          'streamType': CastConstants.streamTypeBuffered,
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
    _castSession!.sendMessage(CastConstants.nsMedia, {
      'type': 'PAUSE',
      'mediaSessionId': _mediaSessionId,
      'requestId': _requestId++,
    });
  }

  void play() {
    if (_castSession == null || _mediaSessionId == null) return;
    debugPrint('CastHandler: Resuming playback');
    _castSession!.sendMessage(CastConstants.nsMedia, {
      'type': 'PLAY',
      'mediaSessionId': _mediaSessionId,
      'requestId': _requestId++,
    });
  }

  void seek(Duration position) {
    if (_castSession == null || _mediaSessionId == null) return;
    debugPrint('CastHandler: Seeking to ${position.inSeconds}s');
    _castSession!.sendMessage(CastConstants.nsMedia, {
      'type': 'SEEK',
      'mediaSessionId': _mediaSessionId,
      'currentTime': position.inSeconds,
      'requestId': _requestId++,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_castSession == null) {
        timer.cancel();
      } else {
        _castSession!.sendMessage(CastConstants.nsHeartbeat, {'type': 'PING'});
      }
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
          _castSession!.sendMessage(CastConstants.nsMedia, {
            'type': 'STOP',
            'mediaSessionId': _mediaSessionId,
            'requestId': _requestId++,
          });
        }

        // 2. Tell the receiver to stop the application entirely
        if (_appSessionId != null) {
          _castSession!.sendMessage(CastConstants.nsReceiver, {
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
    _statusTimer?.cancel();
    _statusTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
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
    _castSession!.sendMessage(CastConstants.nsMedia, {
      'type': 'GET_STATUS',
      'requestId': _requestId++,
    });
  }

  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get duration => _duration;

  // Method _guessMimeType removed in favor of MimeResolver utility.

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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _castSession = null;
  }
}

