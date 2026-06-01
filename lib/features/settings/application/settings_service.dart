import 'dart:convert';
import 'package:cinemuse_app/core/services/streaming/stremio_addon_service.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/core/services/streaming/models/stremio_addon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';

// Simple state class for settings
class UserSettings {
  final String displayName;
  final String appLanguage;
  final String playerLanguage; // General Audio Language
  final bool showSubtitles;
  final String subtitleLanguage;
  final bool splitAnimePreferences;
  final String animeAudioLanguage;
  final bool animeShowSubtitles;
  final String animeSubtitleLanguage;
  final String playerPrimaryColor;
  final String playerSecondaryColor;
  final bool showDebugPanel;
  final bool smartSearchFilter;
  final bool enableAutoSkipProviders;
  final String? liveTvRegion;
  final bool enableAnimeTosho;
  final bool enableVixSrc;
  final bool enableAnimeUnity;
  final bool enableRealDebrid;
  final String realDebridKey;
  final String openSubtitlesKey;
  final bool autoDownloadMissingSubtitles;
  final List<StremioAddon> installedAddons;
  final int liveTvBufferSize; // in MB
  final bool enableLiveTvDiskCache;
  final StreamQuality liveTvQuality;

  const UserSettings({
    this.displayName = '',
    this.appLanguage = 'en',
    this.playerLanguage = 'en',
    this.showSubtitles = true,
    this.subtitleLanguage = 'en',
    this.splitAnimePreferences = false,
    this.animeAudioLanguage = 'en',
    this.animeShowSubtitles = true,
    this.animeSubtitleLanguage = 'en',
    this.playerPrimaryColor = '',
    this.playerSecondaryColor = '',
    this.showDebugPanel = false,
    this.smartSearchFilter = true,
    this.enableAutoSkipProviders = true,
    this.liveTvRegion,
    this.enableAnimeTosho = true,
    this.enableVixSrc = true,
    this.enableAnimeUnity = true,
    this.enableRealDebrid = false,
    this.realDebridKey = '',
    this.openSubtitlesKey = '',
    this.autoDownloadMissingSubtitles = false,
    this.installedAddons = const [],
    this.liveTvBufferSize = 512,
    this.enableLiveTvDiskCache = false,
    this.liveTvQuality = StreamQuality.hd,
  });

  factory UserSettings.fromProfile(Profile profile) {
    final prefs = profile.preferences;
    return UserSettings(
      displayName: profile.username ?? '',
      appLanguage: prefs['appLanguage'] ?? 'en',
      playerLanguage: prefs['playerLanguage'] ?? 'en',
      showSubtitles: prefs['showSubtitles'] ?? true,
      subtitleLanguage: prefs['subtitleLanguage'] ?? 'en',
      splitAnimePreferences: prefs['splitAnimePreferences'] ?? false,
      animeAudioLanguage: prefs['animeAudioLanguage'] ?? 'en',
      animeShowSubtitles: prefs['animeShowSubtitles'] ?? true,
      animeSubtitleLanguage: prefs['animeSubtitleLanguage'] ?? 'en',
      playerPrimaryColor: prefs['playerPrimaryColor'] ?? '',
      playerSecondaryColor: prefs['playerSecondaryColor'] ?? '',
      showDebugPanel: prefs['showDebugPanel'] ?? false,
      smartSearchFilter: prefs['smartSearchFilter'] ?? true,
      enableAutoSkipProviders: prefs['enableAutoSkipProviders'] ?? true,
      liveTvRegion: prefs['liveTvRegion'],
      enableAnimeTosho: prefs['enableAnimeTosho'] ?? true,
      enableVixSrc: prefs['enableVixSrc'] ?? true,
      enableAnimeUnity: prefs['enableAnimeUnity'] ?? true,
      enableRealDebrid: prefs['enableRealDebrid'] ?? false,
      realDebridKey: prefs['realDebridKey'] ?? '',
      openSubtitlesKey: prefs['openSubtitlesKey'] ?? '',
      autoDownloadMissingSubtitles: prefs['autoDownloadMissingSubtitles'] ?? false,
      installedAddons: (prefs['installedAddons'] as Iterable?)?.map((e) {
        if (e is String) {
          return StremioAddon.fromJson(jsonDecode(e) as Map<String, dynamic>);
        }
        return StremioAddon.fromJson(e as Map<String, dynamic>);
      }).toList() ?? const [],
      liveTvBufferSize: prefs['liveTvBufferSize'] ?? 512,
      enableLiveTvDiskCache: prefs['enableLiveTvDiskCache'] ?? false,
      liveTvQuality: StreamQuality.values.firstWhere(
        (e) => e.name == (prefs['liveTvQuality'] as String?),
        orElse: () => StreamQuality.hd,
      ),
    );
  }

  UserSettings copyWith({
    String? displayName,
    String? appLanguage,
    String? playerLanguage,
    bool? showSubtitles,
    String? subtitleLanguage,
    bool? splitAnimePreferences,
    String? animeAudioLanguage,
    bool? animeShowSubtitles,
    String? animeSubtitleLanguage,
    String? playerPrimaryColor,
    String? playerSecondaryColor,
    bool? showDebugPanel,
    bool? smartSearchFilter,
    bool? enableAutoSkipProviders,
    String? liveTvRegion,
    bool? enableAnimeTosho,
    bool? enableVixSrc,
    bool? enableAnimeUnity,
    bool? enableRealDebrid,
    String? realDebridKey,
    String? openSubtitlesKey,
    bool? autoDownloadMissingSubtitles,
    List<StremioAddon>? installedAddons,
    int? liveTvBufferSize,
    bool? enableLiveTvDiskCache,
    StreamQuality? liveTvQuality,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      appLanguage: appLanguage ?? this.appLanguage,
      playerLanguage: playerLanguage ?? this.playerLanguage,
      showSubtitles: showSubtitles ?? this.showSubtitles,
      subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
      splitAnimePreferences: splitAnimePreferences ?? this.splitAnimePreferences,
      animeAudioLanguage: animeAudioLanguage ?? this.animeAudioLanguage,
      animeShowSubtitles: animeShowSubtitles ?? this.animeShowSubtitles,
      animeSubtitleLanguage: animeSubtitleLanguage ?? this.animeSubtitleLanguage,
      playerPrimaryColor: playerPrimaryColor ?? this.playerPrimaryColor,
      playerSecondaryColor: playerSecondaryColor ?? this.playerSecondaryColor,
      showDebugPanel: showDebugPanel ?? this.showDebugPanel,
      smartSearchFilter: smartSearchFilter ?? this.smartSearchFilter,
      enableAutoSkipProviders: enableAutoSkipProviders ?? this.enableAutoSkipProviders,
      liveTvRegion: liveTvRegion ?? this.liveTvRegion,
      enableAnimeTosho: enableAnimeTosho ?? this.enableAnimeTosho,
      enableVixSrc: enableVixSrc ?? this.enableVixSrc,
      enableAnimeUnity: enableAnimeUnity ?? this.enableAnimeUnity,
      enableRealDebrid: enableRealDebrid ?? this.enableRealDebrid,
      realDebridKey: realDebridKey ?? this.realDebridKey,
      openSubtitlesKey: openSubtitlesKey ?? this.openSubtitlesKey,
      autoDownloadMissingSubtitles: autoDownloadMissingSubtitles ?? this.autoDownloadMissingSubtitles,
      installedAddons: installedAddons ?? this.installedAddons,
      liveTvBufferSize: liveTvBufferSize ?? this.liveTvBufferSize,
      enableLiveTvDiskCache: enableLiveTvDiskCache ?? this.enableLiveTvDiskCache,
      liveTvQuality: liveTvQuality ?? this.liveTvQuality,
    );
  }

  Map<String, dynamic> toPreferencesJson() {
    return {
      'appLanguage': appLanguage,
      'playerLanguage': playerLanguage,
      'showSubtitles': showSubtitles,
      'subtitleLanguage': subtitleLanguage,
      'splitAnimePreferences': splitAnimePreferences,
      'animeAudioLanguage': animeAudioLanguage,
      'animeShowSubtitles': animeShowSubtitles,
      'animeSubtitleLanguage': animeSubtitleLanguage,
      'playerPrimaryColor': playerPrimaryColor,
      'playerSecondaryColor': playerSecondaryColor,
      'showDebugPanel': showDebugPanel,
      'smartSearchFilter': smartSearchFilter,
      'enableAutoSkipProviders': enableAutoSkipProviders,
      'liveTvRegion': liveTvRegion,
      'enableAnimeTosho': enableAnimeTosho,
      'enableVixSrc': enableVixSrc,
      'enableAnimeUnity': enableAnimeUnity,
      'enableRealDebrid': enableRealDebrid,
      'realDebridKey': realDebridKey,
      'openSubtitlesKey': openSubtitlesKey,
      'autoDownloadMissingSubtitles': autoDownloadMissingSubtitles,
      'installedAddons': installedAddons.map((e) => e.toJson()).toList(),
      'liveTvBufferSize': liveTvBufferSize,
      'enableLiveTvDiskCache': enableLiveTvDiskCache,
      'liveTvQuality': liveTvQuality.name,
    };
  }
}

class SettingsNotifier extends StateNotifier<UserSettings> {
  final ProfileRepository _profileRepository;
  final Ref _ref;

  SettingsNotifier(this._profileRepository, this._ref) : super(const UserSettings()) {
    initSettings();
  }

  @visibleForTesting
  Future<void> initSettings() async {
    try {
      final user = _ref.read(authProvider).value;
      if (user != null) {
        final profile = await _profileRepository.getProfile(user.id);
        if (profile != null) {
          state = UserSettings.fromProfile(profile);
          // Sync initial app language to localeProvider
          _ref.read(localeProvider.notifier).setLocale(state.appLanguage);
        }
      }
    } catch (e) {
      debugPrint('SettingsService: Failed to initialize settings (offline?). Using defaults.');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final user = _ref.read(authProvider).value;
    if (user == null) return;

    // Update local state first for responsiveness
    state = state.copyWith(
      displayName: updates['displayName'],
      appLanguage: updates['appLanguage'] ?? state.appLanguage,
      playerLanguage: updates['playerLanguage'] ?? state.playerLanguage,
      showSubtitles: updates['showSubtitles'] ?? state.showSubtitles,
      subtitleLanguage: updates['subtitleLanguage'] ?? state.subtitleLanguage,
      splitAnimePreferences: updates['splitAnimePreferences'] ?? state.splitAnimePreferences,
      animeAudioLanguage: updates['animeAudioLanguage'] ?? state.animeAudioLanguage,
      animeShowSubtitles: updates['animeShowSubtitles'] ?? state.animeShowSubtitles,
      animeSubtitleLanguage: updates['animeSubtitleLanguage'] ?? state.animeSubtitleLanguage,
      playerPrimaryColor: updates['playerPrimaryColor'] ?? state.playerPrimaryColor,
      playerSecondaryColor: updates['playerSecondaryColor'] ?? state.playerSecondaryColor,
      showDebugPanel: updates['showDebugPanel'] ?? state.showDebugPanel,
      smartSearchFilter: updates['smartSearchFilter'] ?? state.smartSearchFilter,
      enableAutoSkipProviders: updates['enableAutoSkipProviders'] ?? state.enableAutoSkipProviders,
      liveTvRegion: updates['liveTvRegion'] ?? state.liveTvRegion,
      enableAnimeTosho: updates['enableAnimeTosho'] ?? state.enableAnimeTosho,
      enableVixSrc: updates['enableVixSrc'] ?? state.enableVixSrc,
      enableAnimeUnity: updates['enableAnimeUnity'] ?? state.enableAnimeUnity,
      enableRealDebrid: updates['enableRealDebrid'] ?? state.enableRealDebrid,
      realDebridKey: updates['realDebridKey'] ?? state.realDebridKey,
      openSubtitlesKey: updates['openSubtitlesKey'] ?? state.openSubtitlesKey,
      autoDownloadMissingSubtitles: updates['autoDownloadMissingSubtitles'] ?? state.autoDownloadMissingSubtitles,
      installedAddons: updates['installedAddons'] ?? state.installedAddons,
      liveTvBufferSize: updates['liveTvBufferSize'] ?? state.liveTvBufferSize,
      enableLiveTvDiskCache: updates['enableLiveTvDiskCache'] ?? state.enableLiveTvDiskCache,
      liveTvQuality: updates['liveTvQuality'] ?? state.liveTvQuality,
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

  Future<void> installAddon(String url) async {
    final addonService = _ref.read(stremioAddonServiceProvider);
    final addon = await addonService.fetchManifest(url);
    
    // Check if already installed
    final currentAddons = [...state.installedAddons];
    currentAddons.removeWhere((a) => a.id == addon.id);
    currentAddons.add(addon);
    
    await updateSettings({'installedAddons': currentAddons});
  }

  Future<void> removeAddon(String id) async {
    final currentAddons = [...state.installedAddons];
    currentAddons.removeWhere((a) => a.id == id);
    
    await updateSettings({'installedAddons': currentAddons});
  }

  Future<void> toggleAddon(String id, bool enabled) async {
    final currentAddons = state.installedAddons.map((a) {
      if (a.id == id) return a.copyWith(enabled: enabled);
      return a;
    }).toList();
    
    await updateSettings({'installedAddons': currentAddons});
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  final profileRepo = ref.watch(profileRepositoryProvider);
  final notifier = SettingsNotifier(profileRepo, ref);

  // Listen to auth state changes to reload settings on account switch
  ref.listen(authProvider, (previous, next) {
    if (previous?.value?.id != next.value?.id) {
      notifier.initSettings();
    }
  });

  return notifier;
});
