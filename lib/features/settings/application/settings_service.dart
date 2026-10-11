import 'dart:convert';
import 'package:cinemuse_app/features/streaming/stremio_addon_service.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/profile/data/profile_repository.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/core/application/locale_service.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

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
  final bool smartSearchFilter;
  final bool enableAutoSkipProviders;
  final bool enableAnimeTosho;
  final bool enableVixSrc;
  final bool enableAnimeUnity;
  final bool enableRealDebrid;
  final String realDebridKey;
  final bool enableTorBox;
  final String torBoxKey;
  final String preferredDebridProvider;
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
    this.smartSearchFilter = true,
    this.enableAutoSkipProviders = true,
    this.enableAnimeTosho = true,
    this.enableVixSrc = true,
    this.enableAnimeUnity = true,
    this.enableRealDebrid = false,
    this.realDebridKey = '',
    this.enableTorBox = false,
    this.torBoxKey = '',
    this.preferredDebridProvider = 'realdebrid',
    this.openSubtitlesKey = '',
    this.autoDownloadMissingSubtitles = false,
    this.installedAddons = const [],
    this.liveTvBufferSize = 512,
    this.enableLiveTvDiskCache = false,
    this.liveTvQuality = StreamQuality.hd,
  });

  /// A debrid service is switched on and has a key.
  bool get hasDebrid =>
      (enableRealDebrid && realDebridKey.trim().isNotEmpty) ||
      (enableTorBox && torBoxKey.trim().isNotEmpty);

  /// AnimeTosho only returns torrents, which need a debrid service. The one
  /// rule for the resolver and the settings switch (REV-80).
  bool get isAnimeToshoActive => enableAnimeTosho && hasDebrid;

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
      smartSearchFilter: prefs['smartSearchFilter'] ?? true,
      enableAutoSkipProviders: prefs['enableAutoSkipProviders'] ?? true,
      enableAnimeTosho: prefs['enableAnimeTosho'] ?? true,
      enableVixSrc: prefs['enableVixSrc'] ?? true,
      enableAnimeUnity: prefs['enableAnimeUnity'] ?? true,
      enableRealDebrid: prefs['enableRealDebrid'] ?? false,
      realDebridKey: prefs['realDebridKey'] ?? '',
      enableTorBox: prefs['enableTorBox'] ?? false,
      torBoxKey: prefs['torBoxKey'] ?? '',
      preferredDebridProvider: prefs['preferredDebridProvider'] ?? 'realdebrid',
      openSubtitlesKey: prefs['openSubtitlesKey'] ?? '',
      autoDownloadMissingSubtitles:
          prefs['autoDownloadMissingSubtitles'] ?? false,
      installedAddons:
          (prefs['installedAddons'] as Iterable?)?.map((e) {
            if (e is String) {
              return StremioAddon.fromJson(
                jsonDecode(e) as Map<String, dynamic>,
              );
            }
            return StremioAddon.fromJson(e as Map<String, dynamic>);
          }).toList() ??
          const [],
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
    bool? smartSearchFilter,
    bool? enableAutoSkipProviders,
    bool? enableAnimeTosho,
    bool? enableVixSrc,
    bool? enableAnimeUnity,
    bool? enableRealDebrid,
    String? realDebridKey,
    bool? enableTorBox,
    String? torBoxKey,
    String? preferredDebridProvider,
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
      splitAnimePreferences:
          splitAnimePreferences ?? this.splitAnimePreferences,
      animeAudioLanguage: animeAudioLanguage ?? this.animeAudioLanguage,
      animeShowSubtitles: animeShowSubtitles ?? this.animeShowSubtitles,
      animeSubtitleLanguage:
          animeSubtitleLanguage ?? this.animeSubtitleLanguage,
      smartSearchFilter: smartSearchFilter ?? this.smartSearchFilter,
      enableAutoSkipProviders:
          enableAutoSkipProviders ?? this.enableAutoSkipProviders,
      enableAnimeTosho: enableAnimeTosho ?? this.enableAnimeTosho,
      enableVixSrc: enableVixSrc ?? this.enableVixSrc,
      enableAnimeUnity: enableAnimeUnity ?? this.enableAnimeUnity,
      enableRealDebrid: enableRealDebrid ?? this.enableRealDebrid,
      realDebridKey: realDebridKey ?? this.realDebridKey,
      enableTorBox: enableTorBox ?? this.enableTorBox,
      torBoxKey: torBoxKey ?? this.torBoxKey,
      preferredDebridProvider:
          preferredDebridProvider ?? this.preferredDebridProvider,
      openSubtitlesKey: openSubtitlesKey ?? this.openSubtitlesKey,
      autoDownloadMissingSubtitles:
          autoDownloadMissingSubtitles ?? this.autoDownloadMissingSubtitles,
      installedAddons: installedAddons ?? this.installedAddons,
      liveTvBufferSize: liveTvBufferSize ?? this.liveTvBufferSize,
      enableLiveTvDiskCache:
          enableLiveTvDiskCache ?? this.enableLiveTvDiskCache,
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
      'smartSearchFilter': smartSearchFilter,
      'enableAutoSkipProviders': enableAutoSkipProviders,
      'enableAnimeTosho': enableAnimeTosho,
      'enableVixSrc': enableVixSrc,
      'enableAnimeUnity': enableAnimeUnity,
      'enableRealDebrid': enableRealDebrid,
      'realDebridKey': realDebridKey,
      'enableTorBox': enableTorBox,
      'torBoxKey': torBoxKey,
      'preferredDebridProvider': preferredDebridProvider,
      'openSubtitlesKey': openSubtitlesKey,
      'autoDownloadMissingSubtitles': autoDownloadMissingSubtitles,
      'installedAddons': installedAddons.map((e) => e.toJson()).toList(),
      'liveTvBufferSize': liveTvBufferSize,
      'enableLiveTvDiskCache': enableLiveTvDiskCache,
      'liveTvQuality': liveTvQuality.name,
    };
  }
}

class SettingsNotifier extends Notifier<UserSettings> {
  static const _tag = 'SettingsService';

  // The user whose stored settings are in `state`. Null until a load
  // succeeds: until then `state` holds defaults and must not be saved,
  // because every save writes the whole preferences object.
  String? _loadedUserId;
  Future<void>? _loading;

  @override
  UserSettings build() {
    // Reload on account switch.
    ref.listen(authProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) initSettings();
    });
    // After build: the load sets `state`, which build can't do.
    _loading = Future.microtask(_loadSettings);
    return const UserSettings();
  }

  @visibleForTesting
  Future<void> initSettings() => _loading = _loadSettings();

  Future<void> _loadSettings() async {
    try {
      final user = ref.read(authProvider).value;

      // Account changed: drop the previous user's settings right away.
      if (user?.id != _loadedUserId) {
        _loadedUserId = null;
        state = const UserSettings();
      }
      if (user == null) return;

      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(user.id);

      // Ignore a slow load that finishes after an account switch.
      if (ref.read(authProvider).value?.id != user.id) return;

      if (profile != null) {
        state = UserSettings.fromProfile(profile);
        _loadedUserId = user.id;
        // Sync initial app language to localeProvider
        ref.read(localeProvider.notifier).setLocale(state.appLanguage);
      }
    } catch (e, st) {
      // Safe to continue: `_loadedUserId` stays null, so nothing is saved
      // over the stored settings, and the next save retries the load.
      AppLogger.warn(
        _tag,
        'Failed to load settings (offline?). Using defaults.',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Saves [updates]. The new values show at once; if the write fails the
  /// old values come back and the error is rethrown, so the UI can say so
  /// (REV-78).
  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    // Never save before this user's settings are loaded, or the defaults
    // would overwrite their stored keys and addons.
    if (_loadedUserId != user.id) {
      await _loading; // a load already in progress
      if (_loadedUserId != user.id) await initSettings(); // one retry
      if (_loadedUserId != user.id) {
        throw const NetworkFailure(
          'Settings are still loading. Check your connection and try again.',
        );
      }
    }

    final previous = state;
    // Update local state first for responsiveness
    final updated = state.copyWith(
      displayName: updates['displayName'],
      appLanguage: updates['appLanguage'] ?? state.appLanguage,
      playerLanguage: updates['playerLanguage'] ?? state.playerLanguage,
      showSubtitles: updates['showSubtitles'] ?? state.showSubtitles,
      subtitleLanguage: updates['subtitleLanguage'] ?? state.subtitleLanguage,
      splitAnimePreferences:
          updates['splitAnimePreferences'] ?? state.splitAnimePreferences,
      animeAudioLanguage:
          updates['animeAudioLanguage'] ?? state.animeAudioLanguage,
      animeShowSubtitles:
          updates['animeShowSubtitles'] ?? state.animeShowSubtitles,
      animeSubtitleLanguage:
          updates['animeSubtitleLanguage'] ?? state.animeSubtitleLanguage,
      smartSearchFilter:
          updates['smartSearchFilter'] ?? state.smartSearchFilter,
      enableAutoSkipProviders:
          updates['enableAutoSkipProviders'] ?? state.enableAutoSkipProviders,
      enableAnimeTosho: updates['enableAnimeTosho'] ?? state.enableAnimeTosho,
      enableVixSrc: updates['enableVixSrc'] ?? state.enableVixSrc,
      enableAnimeUnity: updates['enableAnimeUnity'] ?? state.enableAnimeUnity,
      enableRealDebrid: updates['enableRealDebrid'] ?? state.enableRealDebrid,
      realDebridKey: updates['realDebridKey'] ?? state.realDebridKey,
      enableTorBox: updates['enableTorBox'] ?? state.enableTorBox,
      torBoxKey: updates['torBoxKey'] ?? state.torBoxKey,
      preferredDebridProvider:
          updates['preferredDebridProvider'] ?? state.preferredDebridProvider,
      openSubtitlesKey: updates['openSubtitlesKey'] ?? state.openSubtitlesKey,
      autoDownloadMissingSubtitles:
          updates['autoDownloadMissingSubtitles'] ??
          state.autoDownloadMissingSubtitles,
      installedAddons: updates['installedAddons'] ?? state.installedAddons,
      liveTvBufferSize: updates['liveTvBufferSize'] ?? state.liveTvBufferSize,
      enableLiveTvDiskCache:
          updates['enableLiveTvDiskCache'] ?? state.enableLiveTvDiskCache,
      liveTvQuality: updates['liveTvQuality'] ?? state.liveTvQuality,
    );
    state = updated;

    // Sync app language to localeProvider if updated
    if (updates.containsKey('appLanguage')) {
      ref.read(localeProvider.notifier).setLocale(updates['appLanguage']);
    }

    // Prepare DB updates
    final Map<String, dynamic> dbUpdates = {};
    if (updates.containsKey('displayName')) {
      dbUpdates['username'] = updates['displayName'];
    }

    // Always sync the rest to preferences
    dbUpdates['preferences'] = state.toPreferencesJson();

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(user.id, dbUpdates);
    } catch (e, st) {
      AppLogger.warn(
        _tag,
        'Saving settings failed; restoring the old values',
        error: e,
        stackTrace: st,
      );
      // Only undo this change if no newer change replaced it meanwhile.
      if (identical(state, updated)) {
        state = previous;
        if (updates.containsKey('appLanguage')) {
          ref.read(localeProvider.notifier).setLocale(previous.appLanguage);
        }
      }
      rethrow;
    }
  }

  Future<void> installAddon(String url) async {
    final addonService = ref.read(stremioAddonServiceProvider);
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

  /// Puts a removed [addon] back at [index] (the Undo of [removeAddon]).
  Future<void> restoreAddon(StremioAddon addon, int index) async {
    final currentAddons = [...state.installedAddons]
      ..removeWhere((a) => a.id == addon.id);
    currentAddons.insert(index.clamp(0, currentAddons.length), addon);

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

// Lives for the whole session: settings are read everywhere.
final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);
