import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_sources_notifier.dart';
import 'package:cinemuse_app/features/live_tv/data/epg_storage_service.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_guide.dart';

/// The Cinemuse guide's file in the public `livetv` bucket, next to the
/// playlist.
final cinemuseGuideUrlProvider = Provider<String>(
  (ref) => '${SupabaseConfig.url}/storage/v1/object/public/livetv/epg.json',
);

/// Each guide's saved copy on disk. Tests swap the folder.
final epgStorageProvider = Provider<EpgStorageService>(
  (ref) => EpgStorageService(),
);

/// The Cinemuse guide first, then the user's own, saved on this device.
/// When two guides know the same channel, the one higher in the list wins.
class GuidesNotifier extends LiveTvSourcesNotifier<LiveTvGuide> {
  @override
  String get savedKey => 'live_tv_custom_guides';
  @override
  String get builtInEnabledKey => 'live_tv_cinemuse_guide_enabled';
  @override
  String get logTag => 'GuidesNotifier';

  @override
  String watchBuiltInUrl() => ref.watch(cinemuseGuideUrlProvider);

  @override
  LiveTvGuide builtIn(String url, {required bool isEnabled}) =>
      LiveTvGuide.cinemuse(url, isEnabled: isEnabled);

  @override
  LiveTvGuide decode(String saved) => LiveTvGuide.decode(saved);

  @override
  LiveTvGuide withEnabled(LiveTvGuide source, bool isEnabled) =>
      source.copyWith(isEnabled: isEnabled);

  @override
  LiveTvGuide fromLocalFile(String fileName, String storedName) =>
      LiveTvGuide(name: fileName, urlOrPath: storedName, isLocal: true);

  @override
  Future<void> onRemoved(LiveTvGuide source) =>
      ref.read(epgStorageProvider).deleteCachedEpg(source.id);
}

// Not autoDispose: guidesLoadProvider lives for the whole session and reads it.
final guidesProvider = NotifierProvider<GuidesNotifier, List<LiveTvGuide>>(
  GuidesNotifier.new,
);
