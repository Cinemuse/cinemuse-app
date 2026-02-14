import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/supabase_service.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(supabase);
});

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      // TODO: Handle specific errors (network, etc)
      rethrow;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('profiles').update(updates).eq('id', userId);
  }
  
  // Note: Profile creation is handled by Database Trigger on auth.users insert
  // But we might want a manual way if sync fails or for testing
  Future<void> createProfile({
    required String id,
    String? username,
    String? avatarUrl,
  }) async {
    await _client.from('profiles').insert({
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
    });
  }
}
