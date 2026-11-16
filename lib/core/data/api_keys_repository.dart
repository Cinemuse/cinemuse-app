import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final apiKeysRepositoryProvider = Provider<ApiKeysRepository>((ref) {
  return ApiKeysRepository(ref.watch(supabaseClientProvider));
});

/// The TMDB key, downloaded once per session.
///
/// Kept only after a good load, so a failure (offline, no saved copy) is
/// tried again at the next use instead of for the whole session.
final tmdbApiKeyProvider = FutureProvider.autoDispose<String>((ref) async {
  final link = ref.keepAlive();
  try {
    return await ref.watch(apiKeysRepositoryProvider).tmdbKey();
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// Gets the TMDB key; throws an `AppFailure` when there is none.
typedef TmdbKeyLoader = Future<String> Function();

/// The `api_keys` table: the keys of outside services, entered in the
/// Supabase Table Editor. Signed-in users read it, so the app has no key
/// before the first sign-in.
class ApiKeysRepository {
  static const _logTag = 'ApiKeysRepository';
  static const _tmdbRow = 'tmdb';
  static const _savedCopyKey = 'tmdb_api_key';

  final SupabaseClient _client;

  ApiKeysRepository(this._client);

  /// The server's TMDB key, saved on the device; the saved copy when the
  /// server can't be read or has none. Throws an `AppFailure` when neither
  /// is there.
  Future<String> tmdbKey() async {
    try {
      final key = await _fetchTmdbKey();
      await _saveCopy(key);
      return key;
    } on AppFailure catch (e) {
      final copy = await _readCopy();
      if (copy == null) rethrow;
      AppLogger.warn(
        _logTag,
        'TMDB key not read, using the saved copy',
        error: e,
      );
      return copy;
    }
  }

  Future<String> _fetchTmdbKey() async {
    final rows = await _client
        .from('api_keys')
        .select('name, value')
        .withAppFailure();
    for (final row in rows) {
      final value = row['value'];
      if (row['name'] == _tmdbRow && value is String && value.isNotEmpty) {
        return value;
      }
    }
    throw const NotFoundFailure('No TMDB key in api_keys');
  }

  Future<void> _saveCopy(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedCopyKey, key);
    } catch (e) {
      // The key just downloaded is still used; only the offline copy is
      // missing.
      AppLogger.warn(_logTag, 'TMDB key not saved on the device', error: e);
    }
  }

  Future<String?> _readCopy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_savedCopyKey);
      return saved == null || saved.isEmpty ? null : saved;
    } catch (e) {
      AppLogger.warn(_logTag, 'Saved TMDB key unreadable', error: e);
      return null;
    }
  }
}
