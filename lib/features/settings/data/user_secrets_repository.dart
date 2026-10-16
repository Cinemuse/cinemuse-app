import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userSecretsRepositoryProvider = Provider<UserSecretsRepository>((ref) {
  return UserSecretsRepository(ref.watch(supabaseClientProvider));
});

/// The user's API keys and installed addons, in the owner-only
/// `user_secrets.secrets` object instead of `profiles.preferences` (SEC-04).
/// A new key needs no database change: it is one more entry in the object.
class UserSecretsRepository {
  final SupabaseClient _client;

  UserSecretsRepository(this._client);

  /// The user's secrets, or an empty map when they never saved any. Throws
  /// when they can't be read (no offline copy: the keys stay off the device
  /// database).
  Future<Map<String, dynamic>> getSecrets(String userId) async {
    final row = await _client
        .from('user_secrets')
        .select('secrets')
        .eq('user_id', userId)
        .maybeSingle()
        .withErrorHandling();
    final secrets = row?['secrets'];
    return secrets is Map ? Map<String, dynamic>.from(secrets) : const {};
  }

  /// Saves only the keys in [patch] for the signed-in user; the others keep
  /// their stored value.
  Future<void> patchSecrets(Map<String, dynamic> patch) async {
    await _client
        .rpc('patch_secrets', params: {'p_patch': patch})
        .withErrorHandling();
  }
}
