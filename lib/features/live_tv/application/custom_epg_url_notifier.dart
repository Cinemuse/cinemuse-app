import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';

/// The user's own EPG URL, or `null` for the default guide.
///
/// Async so the guide can wait for the saved value instead of first
/// downloading the default guide (REV-115).
class CustomEpgUrlNotifier extends AsyncNotifier<String?> {
  static const _key = 'live_tv_custom_epg_url';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setUrl(String url) async {
    final trimmed = url.trim();
    await _save(trimmed.isEmpty ? null : trimmed);
  }

  Future<void> reset() => _save(null);

  Future<void> _save(String? url) async {
    final previous = state;
    state = AsyncData(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, url);
      }
    } catch (e, s) {
      state = previous;
      throw UnknownFailure(
        'Could not save the EPG URL',
        cause: e,
        stackTrace: s,
      );
    }
  }
}

// Not autoDispose: epgDataProvider lives for the whole session and depends on it.
final customEpgUrlProvider =
    AsyncNotifierProvider<CustomEpgUrlNotifier, String?>(
      CustomEpgUrlNotifier.new,
    );

/// The Cinemuse guide, from the project URL in `.env` (LTV-06).
final defaultEpgUrlProvider = Provider<String>(
  (ref) => '${SupabaseConfig.url}/functions/v1/live-tv-resolver/epg.json',
);

/// Currently active EPG URL (custom URL if configured, otherwise unified default).
final activeEpgUrlProvider = Provider<String>((ref) {
  return ref.watch(customEpgUrlProvider).valueOrNull ??
      ref.watch(defaultEpgUrlProvider);
});
