import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';

// Simple state class for settings
class UserSettings {
  final String displayName;
  final bool enableRealDebrid;
  final String realDebridKey;
  final String appLanguage;
  final String playerLanguage;
  final String playerPrimaryColor;
  final String playerSecondaryColor;
  final bool showDebugPanel;
  final bool smartSearchFilter;
  final String? liveTvRegion;
  final String mediafusionUrl;

  const UserSettings({
    this.displayName = '',
    this.enableRealDebrid = false,
    this.realDebridKey = '',
    this.appLanguage = 'en',
    this.playerLanguage = 'en',
    this.playerPrimaryColor = '',
    this.playerSecondaryColor = '',
    this.showDebugPanel = false,
    this.smartSearchFilter = true,
    this.liveTvRegion,
    this.mediafusionUrl = '',
  });

  factory UserSettings.fromProfile(Profile profile) {
    final prefs = profile.preferences;
    return UserSettings(
      displayName: profile.username ?? '',
      enableRealDebrid: prefs['enableRealDebrid'] ?? false,
      realDebridKey: prefs['realDebridKey'] ?? '',
      appLanguage: prefs['appLanguage'] ?? 'en',
      playerLanguage: prefs['playerLanguage'] ?? 'en',
      playerPrimaryColor: prefs['playerPrimaryColor'] ?? '',
      playerSecondaryColor: prefs['playerSecondaryColor'] ?? '',
      showDebugPanel: prefs['showDebugPanel'] ?? false,
      smartSearchFilter: prefs['smartSearchFilter'] ?? true,
      liveTvRegion: prefs['liveTvRegion'],
      mediafusionUrl: prefs['mediafusionUrl'] ?? '',
    );
  }

  UserSettings copyWith({
    String? displayName,
    bool? enableRealDebrid,
    String? realDebridKey,
    String? appLanguage,
    String? playerLanguage,
    String? playerPrimaryColor,
    String? playerSecondaryColor,
    bool? showDebugPanel,
    bool? smartSearchFilter,
    String? liveTvRegion,
    String? mediafusionUrl,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      enableRealDebrid: enableRealDebrid ?? this.enableRealDebrid,
      realDebridKey: realDebridKey ?? this.realDebridKey,
      appLanguage: appLanguage ?? this.appLanguage,
      playerLanguage: playerLanguage ?? this.playerLanguage,
      playerPrimaryColor: playerPrimaryColor ?? this.playerPrimaryColor,
      playerSecondaryColor: playerSecondaryColor ?? this.playerSecondaryColor,
      showDebugPanel: showDebugPanel ?? this.showDebugPanel,
      smartSearchFilter: smartSearchFilter ?? this.smartSearchFilter,
      liveTvRegion: liveTvRegion ?? this.liveTvRegion,
      mediafusionUrl: mediafusionUrl ?? this.mediafusionUrl,
    );
  }

  Map<String, dynamic> toPreferencesJson() {
    return {
      'enableRealDebrid': enableRealDebrid,
      'realDebridKey': realDebridKey,
      'appLanguage': appLanguage,
      'playerLanguage': playerLanguage,
      'playerPrimaryColor': playerPrimaryColor,
      'playerSecondaryColor': playerSecondaryColor,
      'showDebugPanel': showDebugPanel,
      'smartSearchFilter': smartSearchFilter,
      'liveTvRegion': liveTvRegion,
      'mediafusionUrl': mediafusionUrl,
    };
  }
}

class SettingsNotifier extends StateNotifier<UserSettings> {
  final ProfileRepository _profileRepository;
  final Ref _ref;

  SettingsNotifier(this._profileRepository, this._ref) : super(const UserSettings()) {
    _init();
  }

  Future<void> _init() async {
    final user = _ref.read(authProvider).value;
    if (user != null) {
      final profile = await _profileRepository.getProfile(user.id);
      if (profile != null) {
        state = UserSettings.fromProfile(profile);
        // Sync initial app language to localeProvider
        _ref.read(localeProvider.notifier).setLocale(state.appLanguage);
      }
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final user = _ref.read(authProvider).value;
    if (user == null) return;

    // Update local state first for responsiveness
    state = state.copyWith(
      displayName: updates['displayName'],
      enableRealDebrid: updates['enableRealDebrid'],
      realDebridKey: updates['realDebridKey'],
      appLanguage: updates['appLanguage'],
      playerLanguage: updates['playerLanguage'],
      playerPrimaryColor: updates['playerPrimaryColor'],
      playerSecondaryColor: updates['playerSecondaryColor'],
      showDebugPanel: updates['showDebugPanel'],
      smartSearchFilter: updates['smartSearchFilter'],
      liveTvRegion: updates['liveTvRegion'],
      mediafusionUrl: updates['mediafusionUrl'],
    );

    // Sync app language to localeProvider if updated
    if (updates.containsKey('appLanguage')) {
      _ref.read(localeProvider.notifier).setLocale(updates['appLanguage']);
    }

    // Prepare DB updates
    final Map<String, dynamic> dbUpdates = {};
    if (updates.containsKey('displayName')) {
      dbUpdates['username'] = updates['displayName'];
    }
    
    // Always sync the rest to preferences
    dbUpdates['preferences'] = state.toPreferencesJson();

    await _profileRepository.updateProfile(user.id, dbUpdates);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  final profileRepo = ref.watch(profileRepositoryProvider);
  return SettingsNotifier(profileRepo, ref);
});

