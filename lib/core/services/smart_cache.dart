import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// SmartCache - Local caching utility for Supabase and API data
/// 
/// Provides immediate data from cache while remote streams update.
class SmartCache {
  final String _key;
  SharedPreferences? _prefs;

  SmartCache(this._key);

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Load data from local cache
  Future<Map<String, dynamic>?> loadFromCache() async {
    await _ensurePrefs();
    try {
      final cached = _prefs!.getString(_key);
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      print('SmartCache: Failed to load cache for $_key: $e');
    }
    return null;
  }

  /// Save data to local cache
  Future<void> saveToCache(Map<String, dynamic> data) async {
    await _ensurePrefs();
    try {
      await _prefs!.setString(_key, jsonEncode(data));
    } catch (e) {
      print('SmartCache: Failed to save cache for $_key: $e');
    }
  }

  /// Get the last updated timestamp from cached data
  DateTime? getLastUpdated(Map<String, dynamic>? cachedData) {
    if (cachedData == null || !cachedData.containsKey('updatedAt')) return null;

    final updatedAt = cachedData['updatedAt'];
    
    // Handle numeric timestamp (milliseconds)
    if (updatedAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(updatedAt);
    }
    
    // Handle ISO string
    if (updatedAt is String) {
      return DateTime.tryParse(updatedAt);
    }
    
    return null;
  }

  /// Clear the cache
  Future<void> clearCache() async {
    await _ensurePrefs();
    await _prefs!.remove(_key);
  }
}
