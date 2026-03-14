import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';

enum PlayerSourceKind { vod, youtube, live }

/// Unified resource for anything that can be played.
class PlayableResource {
  final String id;
  final PlayerSourceKind kind;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  
  // VOD specific
  final PlayerParams? vodParams;
  
  // Live TV specific
  final Channel? liveChannel;

  const PlayableResource({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.vodParams,
    this.liveChannel,
  });

  factory PlayableResource.fromVod(PlayerParams params, String title, {String? posterUrl}) {
    return PlayableResource(
      id: params.queryId,
      kind: params.type == 'youtube' ? PlayerSourceKind.youtube : PlayerSourceKind.vod,
      title: title,
      posterUrl: posterUrl,
      vodParams: params,
    );
  }

  factory PlayableResource.fromLive(Channel channel) {
    return PlayableResource(
      id: channel.lcn.toString(),
      kind: PlayerSourceKind.live,
      title: channel.name,
      liveChannel: channel,
    );
  }
}
