import 'package:cinemuse_app/core/error/supabase_failure.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(ref.watch(supabaseClientProvider));
});

/// The one-row `app_config` table, written only by migrations (REV-306).
class AppConfigRepository {
  final SupabaseClient _client;

  AppConfigRepository(this._client);

  /// The oldest app version the database still supports (`1.4.0` or
  /// `1.4.0+21`), or `null` when the row is missing. Throws an `AppFailure`
  /// when it can't be read (offline, server error).
  Future<String?> getMinimumAppVersion() async {
    final row = await _client
        .from('app_config')
        .select('min_app_version')
        .maybeSingle()
        .withAppFailure();
    return row?['min_app_version'] as String?;
  }
}
