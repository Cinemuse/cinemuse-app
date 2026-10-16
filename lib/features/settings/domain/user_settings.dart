import 'dart:convert';

import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';

/// The user's synced settings, stored in `profiles.preferences` (plus the
/// display name in `profiles.username`).
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

  /// Reads the stored settings. A value of the wrong type (e.g. `"true"` as
  /// a string) falls back to its default instead of failing the whole load,
  /// which would block every save for that user (REV-82).
  factory UserSettings.fromProfile(Profile profile) {
    final prefs = profile.preferences;
    const d = UserSettings();

    bool readBool(String key, bool fallback) =>
        prefs[key] is bool ? prefs[key] as bool : fallback;
    String readString(String key, String fallback) =>
        prefs[key] is String ? prefs[key] as String : fallback;

    final bufferSize = prefs['liveTvBufferSize'];
    return UserSettings(
      displayName: profile.username ?? d.displayName,
      appLanguage: readString('appLanguage', d.appLanguage),
      playerLanguage: readString('playerLanguage', d.playerLanguage),
      showSubtitles: readBool('showSubtitles', d.showSubtitles),
      subtitleLanguage: readString('subtitleLanguage', d.subtitleLanguage),
      splitAnimePreferences: readBool(
        'splitAnimePreferences',
        d.splitAnimePreferences,
      ),
      animeAudioLanguage: readString(
        'animeAudioLanguage',
        d.animeAudioLanguage,
      ),
      animeShowSubtitles: readBool('animeShowSubtitles', d.animeShowSubtitles),
      animeSubtitleLanguage: readString(
        'animeSubtitleLanguage',
        d.animeSubtitleLanguage,
      ),
      smartSearchFilter: readBool('smartSearchFilter', d.smartSearchFilter),
      enableAutoSkipProviders: readBool(
        'enableAutoSkipProviders',
        d.enableAutoSkipProviders,
      ),
      enableAnimeTosho: readBool('enableAnimeTosho', d.enableAnimeTosho),
      enableVixSrc: readBool('enableVixSrc', d.enableVixSrc),
      enableAnimeUnity: readBool('enableAnimeUnity', d.enableAnimeUnity),
      enableRealDebrid: readBool('enableRealDebrid', d.enableRealDebrid),
      realDebridKey: readString('realDebridKey', d.realDebridKey),
      enableTorBox: readBool('enableTorBox', d.enableTorBox),
      torBoxKey: readString('torBoxKey', d.torBoxKey),
      preferredDebridProvider: readString(
        'preferredDebridProvider',
        d.preferredDebridProvider,
      ),
      openSubtitlesKey: readString('openSubtitlesKey', d.openSubtitlesKey),
      autoDownloadMissingSubtitles: readBool(
        'autoDownloadMissingSubtitles',
        d.autoDownloadMissingSubtitles,
      ),
      installedAddons: _readAddons(prefs['installedAddons']),
      liveTvBufferSize: bufferSize is num
          ? bufferSize.toInt()
          : d.liveTvBufferSize,
      enableLiveTvDiskCache: readBool(
        'enableLiveTvDiskCache',
        d.enableLiveTvDiskCache,
      ),
      liveTvQuality: StreamQuality.values.firstWhere(
        (e) => e.name == prefs['liveTvQuality'],
        orElse: () => d.liveTvQuality,
      ),
    );
  }

  /// Addons are stored as maps, or as JSON strings by older versions. An
  /// entry that can't be read is skipped, so the other addons still load.
  static List<StremioAddon> _readAddons(Object? raw) {
    if (raw is! Iterable) return const [];
    final addons = <StremioAddon>[];
    for (final entry in raw) {
      try {
        final json = entry is String ? jsonDecode(entry) : entry;
        if (json is Map<String, dynamic>) {
          addons.add(StremioAddon.fromJson(json));
        }
      } on Object {
        // Safe to skip: one broken entry must not hide the user's settings.
        continue;
      }
    }
    return addons;
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

  /// The stored keys whose value differs from [previous], for a save that
  /// writes only what changed (DATA-02b).
  Map<String, dynamic> preferencesChangedSince(UserSettings previous) {
    final before = previous.toPreferencesJson();
    // jsonEncode compares the addon lists by content, not by identity.
    return {
      for (final entry in toPreferencesJson().entries)
        if (jsonEncode(entry.value) != jsonEncode(before[entry.key]))
          entry.key: entry.value,
    };
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
