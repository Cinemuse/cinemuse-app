import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(supabase);
});

class MediaRepository {
  final SupabaseClient _client;

  MediaRepository(this._client);

  Future<MediaItem?> getMediaItem(int tmdbId, MediaKind type) async {
    try {
      final response = await _client
          .from('media_cache')
          .select()
          .eq('tmdb_id', tmdbId)
          .eq('media_type', type.name)
          .maybeSingle();

      if (response == null) return null;
      return MediaItem.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveMediaItem(MediaItem item) async {
    await _client.from('media_cache').upsert(item.toDbJson());
  }
  
  // Future: Method to batch save items
}
