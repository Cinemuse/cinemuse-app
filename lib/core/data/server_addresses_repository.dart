import 'dart:convert';

import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final serverAddressesRepositoryProvider = Provider<ServerAddressesRepository>((
  ref,
) {
  return ServerAddressesRepository(ref.watch(supabaseClientProvider));
});

/// The server's addresses, downloaded once per session (STR-08).
///
/// Kept only after a good load, so a failure (offline, no saved copy) is
/// tried again at the next use instead of for the whole session.
final serverAddressesProvider = FutureProvider.autoDispose<ServerAddresses>((
  ref,
) async {
  final link = ref.keepAlive();
  try {
    return await ref.watch(serverAddressesRepositoryProvider).load();
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// The `server_addresses` table (STR-08): one row per address, with the name
/// the app shows for it, edited by hand in the Supabase Table Editor when a
/// service moves. Signed-in users read it.
class ServerAddressesRepository {
  static const _logTag = 'ServerAddressesRepository';
  // The table's old name: the copy saved before the rename still counts.
  static const _savedCopyKey = 'scraper_sites';

  final SupabaseClient _client;

  ServerAddressesRepository(this._client);

  /// The server's list, saved on the device; the saved copy when the server
  /// can't be read. Throws an `AppFailure` when neither is there.
  Future<ServerAddresses> load() async {
    try {
      final sites = await fetchFromServer();
      await _saveCopy(sites);
      return sites;
    } on AppFailure catch (e) {
      final copy = await _readCopy();
      if (copy == null) rethrow;
      AppLogger.warn(
        _logTag,
        'Address list not read, using the saved copy',
        error: e,
      );
      return copy;
    }
  }

  /// The server's list only (the telemetry has no device copy).
  Future<ServerAddresses> fetchFromServer() async {
    final rows = await _client
        .from('server_addresses')
        .select('key, address, display_name')
        .withAppFailure();
    return ServerAddresses.fromRows(rows);
  }

  Future<void> _saveCopy(ServerAddresses sites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedCopyKey, jsonEncode(sites.toRows()));
    } catch (e) {
      // The list just downloaded is still used; only the offline copy is
      // older.
      AppLogger.warn(_logTag, 'Address list not saved on the device', error: e);
    }
  }

  Future<ServerAddresses?> _readCopy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_savedCopyKey);
      if (saved == null) return null;
      return ServerAddresses.fromRows(jsonDecode(saved) as List);
    } catch (e) {
      // A broken copy, or one saved before the names came, counts as none:
      // the server error is passed on.
      AppLogger.warn(_logTag, 'Saved address list unreadable', error: e);
      return null;
    }
  }
}
