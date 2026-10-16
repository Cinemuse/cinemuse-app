import 'dart:convert';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/supabase_extensions.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/services/system/supabase_service.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:drift/drift.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appDatabaseProvider),
  );
});

class ProfileRepository {
  static const _tag = 'ProfileRepository';

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
        await _db.upsertProfile(
          CachedProfilesCompanion(
            id: Value(profile.id),
            username: Value(profile.username),
            avatarUrl: Value(profile.avatarUrl),
            preferences: Value(jsonEncode(profile.preferences)),
            createdAt: Value(profile.createdAt),
            updatedAt: Value(profile.updatedAt),
          ),
        );
        return profile;
      }
    } catch (e) {
      if (!e.toString().contains('Failed host lookup') &&
          !e.toString().contains('SocketException')) {
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

  /// Saves a new display name as the profile's `username`.
  Future<void> updateUsername(String userId, String username) async {
    await _client
        .from('profiles')
        .update({'username': username})
        .eq('id', userId)
        .withErrorHandling();
    await _updateCache(userId, username: username);
  }

  /// Merges [patch] (only the changed keys) into the stored preferences,
  /// so values this device never changed stay as stored (DATA-02b).
  Future<void> patchPreferences(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    final merged = await _client
        .rpc('patch_preferences', params: {'p_patch': patch})
        .withErrorHandling();
    await _updateCache(
      userId,
      preferences: Map<String, dynamic>.from(merged as Map),
    );
  }

  /// Best effort: the remote write already succeeded, and the next
  /// [getProfile] online refreshes the cache anyway.
  Future<void> _updateCache(
    String userId, {
    String? username,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final cached = await _db.getCachedProfile(userId);
      if (cached == null) return;
      await _db.upsertProfile(
        CachedProfilesCompanion(
          id: Value(userId),
          username: Value(username ?? cached.username),
          avatarUrl: Value(cached.avatarUrl),
          preferences: Value(
            preferences != null ? jsonEncode(preferences) : cached.preferences,
          ),
          createdAt: Value(cached.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'Failed to update the local profile cache',
        error: e,
        stackTrace: st,
      );
    }
  }
}
