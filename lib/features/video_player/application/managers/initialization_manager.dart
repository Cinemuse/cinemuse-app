import 'dart:async';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/rd_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/vod_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_source_handler.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';

/// Centralized manager for orchestrating player initialization logic.
class InitializationManager extends BaseManager {
  final YoutubeHandler youtubeHandler;
  final RdHandler rdHandler;
  final UnifiedStreamResolver resolver;
  final TmdbService tmdbService;

  InitializationManager({
    required super.ref,
    required super.player,
    required this.youtubeHandler,
    required this.rdHandler,
    required this.resolver,
    required this.tmdbService,
  });

  Future<YouTubeInitializationResult> initializeYouTube(PlayerParams params) async {
    final handler = YouTubeSourceHandler(youtubeHandler, player);
    return await handler.initialize(params);
  }

  Future<VodInitializationResult> initializeVod(
    PlayerParams params, {
    required Function(List<ProviderSearchStatus>) onStatusUpdate,
    required Function(Map<String, dynamic>?) onMediaDetailsFetched,
  }) async {
    final handler = VodSourceHandler(rdHandler, resolver, tmdbService, player);
    return await handler.initialize(
      params, 
      onStatusUpdate: onStatusUpdate,
      onMediaDetailsFetched: onMediaDetailsFetched,
    );
  }

  Future<LiveTvInitializationResult> initializeLiveTv(Channel channel) async {
    final settings = ref.read(settingsProvider);
    final handler = LiveTvSourceHandler(player);
    return await handler.initialize(channel, settings);
  }
}
