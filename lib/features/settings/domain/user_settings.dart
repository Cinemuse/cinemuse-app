import 'dart:convert';

import 'package:cinemuse_app/features/profile/domain/profile.dart';
import 'package:cinemuse_app/features/streaming/models/stremio_addon.dart';

/// The user's synced settings, stored in `profiles.preferences` (plus the
/// display name in `profiles.username`); the API keys and addons are in the
/// owner-only `user_secrets` row (SEC-04).
class UserSettings {
  final String displayName;
  final String appLanguage;

  /// The country for streaming services (Explore's provider filter), a
  /// TMDB `iso_3166_1` code.
  final String watchRegion;
  final String playerLanguage; // General Audio Language
  final bool showSubtitles;
  final String subtitleLanguage;
  final bool splitAnimePreferences;
  final String animeAudioLanguage;
  final bool animeShowSubtitles;
  final String animeSubtitleLanguage;
  final bool smartSearchFilter;
  final bool enableAutoSkipProviders;
  final bool enableAnimeTorrents;
  final bool enableMovieSite;
  final bool enableAnimeSite;
  final bool enableRealDebrid;
  final String realDebridKey;
  final bool enableTorBox;
  final String torBoxKey;
  final String preferredDebridProvider;
  final String openSubtitlesKey;
  final bool autoDownloadMissingSubtitles;
  final List<StremioAddon> installedAddons;

  /// How far back a live channel can be rewound, in minutes (one of
  /// [liveTvRewindChoices]). The player keeps less when memory is short.
  final int liveTvRewindMinutes;

  static const liveTvRewindChoices = [2, 5, 15, 30, 60];

  const UserSettings({
    this.displayName = '',
    this.appLanguage = 'en',
    this.watchRegion = 'IT',
    this.playerLanguage = 'en',
    this.showSubtitles = true,
    this.subtitleLanguage = 'en',
    this.splitAnimePreferences = false,
    this.animeAudioLanguage = 'en',
    this.animeShowSubtitles = true,
    this.animeSubtitleLanguage = 'en',
    this.smartSearchFilter = true,
    this.enableAutoSkipProviders = true,
    this.enableAnimeTorrents = true,
    this.enableMovieSite = true,
    this.enableAnimeSite = true,
    this.enableRealDebrid = false,
    this.realDebridKey = '',
    this.enableTorBox = false,
    this.torBoxKey = '',
    this.preferredDebridProvider = 'realdebrid',
    this.openSubtitlesKey = '',
    this.autoDownloadMissingSubtitles = false,
    this.installedAddons = const [],
    this.liveTvRewindMinutes = 5,
  });

  /// A debrid service is switched on and has a key.
  bool get hasDebrid =>
      (enableRealDebrid && realDebridKey.trim().isNotEmpty) ||
      (enableTorBox && torBoxKey.trim().isNotEmpty);

  /// The anime torrent feed only returns torrents, which need a debrid service. The one
  /// rule for the resolver and the settings switch (REV-80).
  bool get isAnimeTorrentsActive => enableAnimeTorrents && hasDebrid;

  /// Reads the stored settings from the profile and the [secrets] object. A
  /// value of the wrong type (e.g. `"true"` as a string) falls back to its
  /// default instead of failing the whole load, which would block every save
  /// for that user (REV-82).
  factory UserSettings.fromProfile(
    Profile profile, {
    Map<String, dynamic> secrets = const {},
  }) {
    final prefs = profile.preferences;
    const d = UserSettings();

    bool readBool(String key, bool fallback) =>
        prefs[key] is bool ? prefs[key] as bool : fallback;
    String readString(String key, String fallback) =>
        prefs[key] is String ? prefs[key] as String : fallback;
    String readSecret(String key) =>
        secrets[key] is String ? secrets[key] as String : '';

    final rewindMinutes = prefs['liveTvRewindMinutes'];
    return UserSettings(
      displayName: profile.username ?? d.displayName,
      appLanguage: readString('appLanguage', d.appLanguage),
      watchRegion: readString('watchRegion', d.watchRegion),
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
      enableAnimeTorrents: readBool(
        'enableAnimeTorrents',
        d.enableAnimeTorrents,
      ),
      enableMovieSite: readBool('enableMovieSite', d.enableMovieSite),
      enableAnimeSite: readBool('enableAnimeSite', d.enableAnimeSite),
      enableRealDebrid: readBool('enableRealDebrid', d.enableRealDebrid),
      realDebridKey: readSecret('realDebridKey'),
      enableTorBox: readBool('enableTorBox', d.enableTorBox),
      torBoxKey: readSecret('torBoxKey'),
      preferredDebridProvider: readString(
        'preferredDebridProvider',
        d.preferredDebridProvider,
      ),
      openSubtitlesKey: readSecret('openSubtitlesKey'),
      autoDownloadMissingSubtitles: readBool(
        'autoDownloadMissingSubtitles',
        d.autoDownloadMissingSubtitles,
      ),
      installedAddons: _readAddons(secrets['installedAddons']),
      liveTvRewindMinutes:
          rewindMinutes is int && liveTvRewindChoices.contains(rewindMinutes)
          ? rewindMinutes
          : d.liveTvRewindMinutes,
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
    String? watchRegion,
    String? playerLanguage,
    bool? showSubtitles,
    String? subtitleLanguage,
    bool? splitAnimePreferences,
    String? animeAudioLanguage,
    bool? animeShowSubtitles,
    String? animeSubtitleLanguage,
    bool? smartSearchFilter,
    bool? enableAutoSkipProviders,
    bool? enableAnimeTorrents,
    bool? enableMovieSite,
    bool? enableAnimeSite,
    bool? enableRealDebrid,
    String? realDebridKey,
    bool? enableTorBox,
    String? torBoxKey,
    String? preferredDebridProvider,
    String? openSubtitlesKey,
    bool? autoDownloadMissingSubtitles,
    List<StremioAddon>? installedAddons,
    int? liveTvRewindMinutes,
  }) {
    return UserSettings(
      displayName: displayName ?? this.displayName,
      appLanguage: appLanguage ?? this.appLanguage,
      watchRegion: watchRegion ?? this.watchRegion,
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
      enableAnimeTorrents: enableAnimeTorrents ?? this.enableAnimeTorrents,
      enableMovieSite: enableMovieSite ?? this.enableMovieSite,
      enableAnimeSite: enableAnimeSite ?? this.enableAnimeSite,
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
      liveTvRewindMinutes: liveTvRewindMinutes ?? this.liveTvRewindMinutes,
    );
  }

  /// The preferences whose value differs from [previous], for a save that
  /// writes only what changed (DATA-02b).
  Map<String, dynamic> preferencesChangedSince(UserSettings previous) =>
      _changedEntries(toPreferencesJson(), previous.toPreferencesJson());

  /// The `user_secrets.secrets` keys whose value differs from [previous].
  Map<String, dynamic> secretsChangedSince(UserSettings previous) =>
      _changedEntries(toSecretsJson(), previous.toSecretsJson());

  static Map<String, dynamic> _changedEntries(
    Map<String, dynamic> now,
    Map<String, dynamic> before,
  ) {
    // jsonEncode compares the addon lists by content, not by identity.
    return {
      for (final entry in now.entries)
        if (jsonEncode(entry.value) != jsonEncode(before[entry.key]))
          entry.key: entry.value,
    };
  }

  Map<String, dynamic> toPreferencesJson() {
    return {
      'appLanguage': appLanguage,
      'watchRegion': watchRegion,
      'playerLanguage': playerLanguage,
      'showSubtitles': showSubtitles,
      'subtitleLanguage': subtitleLanguage,
      'splitAnimePreferences': splitAnimePreferences,
      'animeAudioLanguage': animeAudioLanguage,
      'animeShowSubtitles': animeShowSubtitles,
      'animeSubtitleLanguage': animeSubtitleLanguage,
      'smartSearchFilter': smartSearchFilter,
      'enableAutoSkipProviders': enableAutoSkipProviders,
      'enableAnimeTorrents': enableAnimeTorrents,
      'enableMovieSite': enableMovieSite,
      'enableAnimeSite': enableAnimeSite,
      'enableRealDebrid': enableRealDebrid,
      'enableTorBox': enableTorBox,
      'preferredDebridProvider': preferredDebridProvider,
      'autoDownloadMissingSubtitles': autoDownloadMissingSubtitles,
      'liveTvRewindMinutes': liveTvRewindMinutes,
    };
  }

  /// The `user_secrets.secrets` object (SEC-04): never in `profiles.preferences`.
  Map<String, dynamic> toSecretsJson() {
    return {
      'realDebridKey': realDebridKey,
      'torBoxKey': torBoxKey,
      'openSubtitlesKey': openSubtitlesKey,
      'installedAddons': installedAddons.map((e) => e.toJson()).toList(),
    };
  }
}
