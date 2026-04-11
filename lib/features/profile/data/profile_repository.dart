import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:drift/drift.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(supabase, ref.watch(appDatabaseProvider));
});

class ProfileRepository {
  final SupabaseClient _client;
  final AppDatabase _db;

  ProfileRepository(this._client, this._db);

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .withErrorHandling();

      if (response != null) {
        final profile = Profile.fromJson(response);
        // Sync to local cache
        await _db.upsertProfile(CachedProfilesCompanion(
          id: Value(profile.id),
          username: Value(profile.username),
          avatarUrl: Value(profile.avatarUrl),
          preferences: Value(jsonEncode(profile.preferences)),
          createdAt: Value(profile.createdAt),
          updatedAt: Value(profile.updatedAt),
        ));
        return profile;
      }
    } catch (e) {
      if (!e.toString().contains('Failed host lookup') && !e.toString().contains('SocketException')) {
        debugPrint('ProfileRepository: Network error fetching profile: $e');
      }
    }

    // Fallback to local cache
    final cached = await _db.getCachedProfile(userId);
    if (cached != null) {
      return Profile(
        id: cached.id,
        username: cached.username,
        avatarUrl: cached.avatarUrl,
        preferences: cached.preferences != null 
            ? jsonDecode(cached.preferences!) as Map<String, dynamic> 
            : {},
        createdAt: cached.createdAt,
        updatedAt: cached.updatedAt,
      );
    }

    return null;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    // 1. Update Remote
    await _client.from('profiles').update(updates).eq('id', userId).withErrorHandling();

    // 2. Update Local Cache (Best effort)
    try {
      final cached = await _db.getCachedProfile(userId);
      if (cached != null) {
        final Map<String, dynamic> currentPrefs = cached.preferences != null 
            ? jsonDecode(cached.preferences!) as Map<String, dynamic> 
            : {};
        
        final updatedPrefs = {...currentPrefs, ...?updates['preferences']};
        
        await _db.upsertProfile(CachedProfilesCompanion(
          id: Value(userId),
          username: Value(updates['username'] ?? cached.username),
          avatarUrl: Value(updates['avatar_url'] ?? cached.avatarUrl),
          preferences: Value(jsonEncode(updatedPrefs)),
          createdAt: Value(cached.createdAt),
          updatedAt: Value(DateTime.now()),
        ));
      }
    } catch (e) {
      debugPrint('ProfileRepository: Failed to update local cache: $e');
    }
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
    }).withErrorHandling();
  }
}
