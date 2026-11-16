import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_sources_notifier.dart';
import 'package:cinemuse_app/features/live_tv/data/playlist_copy_storage.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';

/// The Cinemuse playlist's file in the public `livetv` bucket.
final cinemusePlaylistUrlProvider = Provider<String>(
  (ref) => '${SupabaseConfig.url}/storage/v1/object/public/livetv/playlist.m3u',
);

/// Each downloaded playlist's saved copy on disk. Tests swap the folder.
final playlistCopyStorageProvider = Provider<PlaylistCopyStorage>(
  (ref) => PlaylistCopyStorage(),
);

/// The Cinemuse playlist first, then the user's own, saved on this device.
class PlaylistsNotifier extends LiveTvSourcesNotifier<LiveTvPlaylist> {
  @override
  String get savedKey => 'live_tv_custom_playlists';
  @override
  String get builtInEnabledKey => 'live_tv_cinemuse_playlist_enabled';
  @override
  String get logTag => 'PlaylistsNotifier';

  @override
  String watchBuiltInUrl() => ref.watch(cinemusePlaylistUrlProvider);

  @override
  LiveTvPlaylist builtIn(String url, {required bool isEnabled}) =>
      LiveTvPlaylist.cinemuse(url, isEnabled: isEnabled);

  @override
  LiveTvPlaylist decode(String saved) => LiveTvPlaylist.decode(saved);

  @override
  LiveTvPlaylist withEnabled(LiveTvPlaylist source, bool isEnabled) =>
      source.copyWith(isEnabled: isEnabled);

  @override
  LiveTvPlaylist fromLocalFile(String fileName, String storedName) =>
      LiveTvPlaylist(
        name: fileName,
        urlOrPath: storedName,
        isLocal: true,
        type: PlaylistType.fromPath(fileName),
      );

  @override
  Future<void> onRemoved(LiveTvPlaylist source) =>
      ref.read(playlistCopyStorageProvider).delete(source.id);
}

// Not autoDispose: channelsLoadProvider lives for the whole session and reads
// it.
final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, List<LiveTvPlaylist>>(
      PlaylistsNotifier.new,
    );
