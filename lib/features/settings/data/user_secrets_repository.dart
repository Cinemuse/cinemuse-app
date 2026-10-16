import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userSecretsRepositoryProvider = Provider<UserSecretsRepository>((ref) {
  return UserSecretsRepository(ref.watch(supabaseClientProvider));
});

/// The user's API keys and installed addons, in the owner-only
/// `user_secrets` table instead of `profiles.preferences` (SEC-04).
class UserSecretsRepository {
  final SupabaseClient _client;

  UserSecretsRepository(this._client);

  /// The user's row, or an empty map when they never saved one. Throws when
  /// it can't be read (no offline copy: the keys stay off the device
  /// database).
  Future<Map<String, dynamic>> getSecrets(String userId) async {
    final row = await _client
        .from('user_secrets')
        .select()
        .eq('user_id', userId)
        .maybeSingle()
        .withErrorHandling();
    return row ?? const {};
  }

  /// Saves only the columns in [patch]; the others keep their stored value.
  Future<void> patchSecrets(String userId, Map<String, dynamic> patch) async {
    await _client.from('user_secrets').upsert({
      ...patch,
      'user_id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).withErrorHandling();
  }
}
