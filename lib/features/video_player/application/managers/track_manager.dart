import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/track_choices.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:media_kit/media_kit.dart';

/// External subtitle search results for one player, keyed by the params the
/// screen opened it with. Filled by [TrackManager], read by the UI.
class ExternalSubtitlesNotifier
    extends Notifier<AsyncValue<List<ExternalSubtitle>>> {
  // The family key: one notifier per player.
  ExternalSubtitlesNotifier(PlayerParams _);

  @override
  AsyncValue<List<ExternalSubtitle>> build() => const AsyncValue.loading();

  void setResults(AsyncValue<List<ExternalSubtitle>> value) => state = value;
}

final externalSubtitlesProvider = NotifierProvider.autoDispose
    .family<
      ExternalSubtitlesNotifier,
      AsyncValue<List<ExternalSubtitle>>,
      PlayerParams
    >(ExternalSubtitlesNotifier.new);

/// The subtitles the file itself marks as forced or for the deaf, by track
/// id, for one player. Filled by [TrackManager], read by the subtitles panel.
class SubtitleFlagsNotifier extends Notifier<Map<String, SubtitleKind>> {
  // The family key: one notifier per player.
  SubtitleFlagsNotifier(PlayerParams _);

  @override
  Map<String, SubtitleKind> build() => const {};

  void set(Map<String, SubtitleKind> value) => state = value;
}

final subtitleFlagsProvider = NotifierProvider.autoDispose
    .family<SubtitleFlagsNotifier, Map<String, SubtitleKind>, PlayerParams>(
      SubtitleFlagsNotifier.new,
    );

/// The address of the subtitle the player is fetching for the user's pick,
/// for one player; null when none. Filled by [TrackManager], read by the
/// subtitles panel, which shows that row as loading.
class FetchingSubtitleNotifier extends Notifier<String?> {
  // The family key: one notifier per player.
  FetchingSubtitleNotifier(PlayerParams _);

  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final fetchingSubtitleProvider = NotifierProvider.autoDispose
    .family<FetchingSubtitleNotifier, String?, PlayerParams>(
      FetchingSubtitleNotifier.new,
    );

/// Reads from the engine's track list (through [read], one property at a
/// time) the subtitle tracks the file marks as forced or hearing impaired,
/// by track id: media_kit's tracks don't carry these flags. A flag the
/// engine doesn't know (Android's older mpv has no `hearing-impaired`)
/// reads as off.
Future<Map<String, SubtitleKind>> readSubtitleFlags(
  Future<String> Function(String property) read,
) async {
  Future<bool> flag(String property) async {
    final value = await read(property);
    return value == 'yes' || value == 'true';
  }

  final count = int.tryParse(await read('track-list/count')) ?? 0;
  final flags = <String, SubtitleKind>{};
  for (var i = 0; i < count; i++) {
    if (await read('track-list/$i/type') != 'sub') continue;
    final id = await read('track-list/$i/id');
    if (await flag('track-list/$i/forced')) {
      flags[id] = SubtitleKind.forced;
    } else if (await flag('track-list/$i/hearing-impaired')) {
      flags[id] = SubtitleKind.cc;
    }
  }
  return flags;
}

/// What [TrackManager.recoverFromAudioError] did about a sound error.
enum AudioErrorRecovery {
  /// Another audio track of the file is now on.
  switchedTrack,

  /// No audio track of the file can be decoded: the source is dead.
  noTrackLeft,
}

/// Manages automatic track (audio & subtitle) selection based on user preferences.
///
/// Reactively listens to [player.stream.tracks] and selects the preferred tracks
/// whenever the track list changes (e.g., after demuxing or external subtitle injection).
/// Also handles background fetching of external subtitles and auto-applying the best match.
class TrackManager {
  final Ref ref;
  final Player player;

  /// Resolved params (with season/episode filled in), used for the search.
  final PlayerParams params;

  /// The params the screen opened the player with: the UI reads
  /// [externalSubtitlesProvider] with these, so the results go there (REV-142).
  final PlayerParams subtitlesKey;

  TrackManager({
    required this.ref,
    required this.player,
    required this.params,
    required this.subtitlesKey,
  }) {
    _tracksSubscription = player.stream.tracks.listen(
      (_) => _onTracksChanged(),
    );
    // Keeps the auto-dispose results alive until the player closes, so they
    // are still there when the user opens the subtitles panel later.
    _subtitlesSubscription = ref.listen(
      externalSubtitlesProvider(subtitlesKey),
      (_, _) {},
    );
    _flagsSubscription = ref.listen(
      subtitleFlagsProvider(subtitlesKey),
      (_, _) {},
    );
    _fetchingSubscription = ref.listen(
      fetchingSubtitleProvider(subtitlesKey),
      (_, _) {},
    );
  }

  StreamSubscription? _tracksSubscription;
  ProviderSubscription? _subtitlesSubscription;
  ProviderSubscription? _flagsSubscription;
  ProviderSubscription? _fetchingSubscription;

  /// What the file says of its subtitle tracks, by id; [_flagsReadFor]
  /// holds the track ids they were read for.
  Map<String, SubtitleKind> _flagged = const {};
  String? _flagsReadFor;
  bool _isAutoSelecting = true;
  bool _isPerformingSelection = false;
  bool _hasFetchedExternal = false;
  bool? _isAnime;
  Timer? _autoSelectTimeout;

  /// Audio codecs the engine failed to decode (e.g. `truehd`): their tracks
  /// are skipped by the automatic choice until the player closes.
  final Set<String> _undecodableCodecs = {};

  /// mpv's error when it has no decoder for a track's codec; it then plays
  /// the picture in silence.
  static final _decoderError = RegExp(
    r"failed to initialize a decoder for codec '([^']+)'",
    caseSensitive: false,
  );

  void dispose() {
    _tracksSubscription?.cancel();
    _subtitlesSubscription?.close();
    _flagsSubscription?.close();
    _fetchingSubscription?.close();
    _autoSelectTimeout?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Turns on [track], an [AudioTrack] or a [SubtitleTrack]: the user's
  /// pick, so the automatic choice stops. Throws [StreamingFailure] if the
  /// player refuses it.
  Future<void> selectTrack(Object track) {
    return switch (track) {
      final AudioTrack audio => _turnOnPick(
        'audio track ${audio.id}',
        () => player.setAudioTrack(audio),
      ),
      final SubtitleTrack subtitle when subtitle.uri => _turnOnLink(subtitle),
      final SubtitleTrack subtitle => _turnOnPick(
        'subtitle track ${subtitle.id}',
        () => player.setSubtitleTrack(subtitle),
      ),
      _ => throw ArgumentError.value(track, 'track', 'Not a track'),
    };
  }

  /// A subtitle the stream lists by its address: the player fetches it
  /// (seconds, for a long one), so it is fetched once. A pick while it is
  /// on its way does nothing; once loaded, its track is turned on instead.
  Future<void> _turnOnLink(SubtitleTrack link) async {
    final loaded = loadedCopyOf(link, player.state.tracks.subtitle);
    if (loaded != null) {
      return _turnOnPick(
        'subtitle track ${loaded.id}',
        () => player.setSubtitleTrack(loaded),
      );
    }
    final fetching = fetchingSubtitleProvider(subtitlesKey);
    if (ref.read(fetching) == link.id) return;
    ref.read(fetching.notifier).set(link.id);
    try {
      await _turnOnPick(
        'subtitle ${link.title}',
        () => player.setSubtitleTrack(link),
      );
    } finally {
      // The player may have closed meanwhile; a later pick keeps its row.
      if (ref.mounted && ref.read(fetching) == link.id) {
        ref.read(fetching.notifier).set(null);
      }
    }
  }

  /// Downloads [subtitle] and turns it on, like [selectTrack]. Throws
  /// [StreamingFailure] if it has no link or the player refuses it.
  Future<void> applyExternalSubtitle(ExternalSubtitle subtitle) =>
      _turnOnPick('external subtitle ${subtitle.title}', () async {
        final url = await ref
            .read(subtitleServiceProvider)
            .getDownloadUrl(subtitle);
        if (url == null || url.isEmpty) {
          throw const NotFoundFailure('The subtitle has no download link');
        }
        await player.setSubtitleTrack(
          SubtitleTrack.uri(
            url,
            title: subtitle.title,
            language: subtitle.language,
          ),
        );
      });

  /// For an engine [error] about an audio track's codec: turns on another
  /// audio track the engine can decode, the preferred language first. Null
  /// when [error] isn't about an audio track (a video codec, the network…).
  AudioErrorRecovery? recoverFromAudioError(String error) {
    final codec = _decoderError.firstMatch(error)?.group(1);
    if (codec == null) return null;
    final tracks = player.state.tracks.audio;
    if (!tracks.any((t) => isRealTrack(t) && t.codec == codec)) return null;

    _undecodableCodecs.add(codec);
    final language = preferredAudioLanguage(
      ref.read(settingsProvider),
      isAnime: _isAnime ?? false,
    );
    final next = autoPickedTrack(_playable(tracks), language) as AudioTrack?;
    if (next == null) return AudioErrorRecovery.noTrackLeft;

    AppLogger.warn(
      'TrackManager',
      'No decoder for $codec: switching to audio track ${next.id}',
    );
    unawaited(
      player.setAudioTrack(next).catchError((Object e, StackTrace st) {
        AppLogger.warn(
          'TrackManager',
          'Could not turn on audio track ${next.id}',
          error: e,
          stackTrace: st,
        );
      }),
    );
    return AudioErrorRecovery.switchedTrack;
  }

  /// Whether the file now open has a sound track in [language]: waits up
  /// to [wait] for its sound tracks (opening a file clears the old ones).
  Future<SoundLanguage> soundLanguage(
    String language, {
    Duration wait = const Duration(seconds: 15),
  }) async {
    var tracks = player.state.tracks.audio;
    if (!tracks.any(isRealTrack)) {
      try {
        final listed = await player.stream.tracks
            .firstWhere((t) => t.audio.any(isRealTrack))
            .timeout(wait);
        tracks = listed.audio;
      } on TimeoutException {
        return SoundLanguage.unknown;
      } on StateError {
        return SoundLanguage.unknown; // the player closed meanwhile
      }
    }
    return soundLanguageOf(tracks, language);
  }

  /// [tracks] without the ones whose codec the engine can't decode.
  List<AudioTrack> _playable(List<AudioTrack> tracks) =>
      tracks.where((t) => !_undecodableCodecs.contains(t.codec)).toList();

  /// Runs [turnOn]. The automatic choice waits meanwhile, so a track list
  /// that changes during a slow pick doesn't undo it; it stops for good
  /// only once the pick worked, so a failed one leaves the preferred track
  /// coming (REV-173).
  Future<void> _turnOnPick(String what, Future<void> Function() turnOn) async {
    final wasAutoSelecting = _isAutoSelecting;
    _isAutoSelecting = false;
    try {
      await turnOn();
    } catch (e, st) {
      _isAutoSelecting =
          wasAutoSelecting && (_autoSelectTimeout?.isActive ?? false);
      AppLogger.warn(
        'TrackManager',
        'Could not turn on $what',
        error: e,
        stackTrace: st,
      );
      throw StreamingFailure(
        'Could not turn on $what',
        cause: e,
        stackTrace: st,
      );
    }
    _isAutoSelecting = false;
    _autoSelectTimeout?.cancel();
  }

  /// Sets MPV engine properties (`alang`, `slang`) for instant track matching.
  void applyEnginePreferences({bool isAnime = false}) {
    final settings = ref.read(settingsProvider);
    final audioLang = preferredAudioLanguage(settings, isAnime: isAnime);
    final subLang = preferredSubtitleLanguage(settings, isAnime: isAnime);
    if (audioLang.isEmpty) return;

    try {
      final audioCodes = LanguageMapper.getCodes(audioLang).join(',');
      final subCodes = LanguageMapper.getCodes(subLang).join(',');
      final platform = player.platform as dynamic;
      platform.setProperty('alang', audioCodes);
      platform.setProperty('slang', subCodes);
      // Disable auto-showing forced subtitles as an overlay
      platform.setProperty('sub-forced-events-only', 'no');
    } catch (e, s) {
      // Only the instant match is lost: the reactive selection still runs.
      AppLogger.warn(
        'TrackManager',
        'Failed to set alang/slang platform properties on player',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Enables reactive track selection once `isAnime` is known.
  /// Checks existing tracks immediately and fetches external subtitles in background.
  Future<void> ensurePreferredTrack({bool isAnime = false}) async {
    _isAnime = isAnime;
    _isAutoSelecting = true;
    _hasFetchedExternal = false;

    final settings = ref.read(settingsProvider);
    if (preferredAudioLanguage(settings, isAnime: isAnime).isEmpty) {
      return;
    }

    _startAutoSelectTimeout();
    unawaited(_fetchAndCacheExternalSubtitles());

    if (_hasRealTracks()) {
      await _performSelection();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings helpers
  // ---------------------------------------------------------------------------

  bool _preferredShowSubs(UserSettings s, bool isAnime) =>
      (s.splitAnimePreferences && isAnime)
      ? s.animeShowSubtitles
      : s.showSubtitles;

  // ---------------------------------------------------------------------------
  // Track selection
  // ---------------------------------------------------------------------------

  bool _hasRealTracks() => player.state.tracks.audio.any(isRealTrack);

  void _startAutoSelectTimeout() {
    _autoSelectTimeout?.cancel();
    _autoSelectTimeout = Timer(
      const Duration(seconds: 20),
      () => _isAutoSelecting = false,
    );
  }

  void _onTracksChanged() {
    if (!_isAutoSelecting ||
        _isAnime == null ||
        _isPerformingSelection ||
        !_hasRealTracks()) {
      return;
    }
    _performSelection();
  }

  Future<void> _performSelection() async {
    if (_isPerformingSelection) return;
    _isPerformingSelection = true;

    try {
      final settings = ref.read(settingsProvider);
      final isAnime = _isAnime ?? false;
      final audioLang = preferredAudioLanguage(settings, isAnime: isAnime);
      final subLang = preferredSubtitleLanguage(settings, isAnime: isAnime);
      final showSubs = _preferredShowSubs(settings, isAnime);
      if (audioLang.isEmpty) return;

      final audio = await _selectAudioTrack(audioLang);
      await _readSubtitleFlags();

      if (!showSubs) {
        await _showForcedSubtitlesOnly(audio, audioLang);
        return;
      }

      final matched = await _selectSubtitleTrack(subLang);

      if (!matched && !_hasFetchedExternal) {
        _hasFetchedExternal = true;
        unawaited(_autoApplyBestExternalSubtitle(subLang));
      }
    } finally {
      _isPerformingSelection = false;
    }
  }

  /// Selects the first playable audio track matching [lang], or falls back to
  /// the first playable real track. Returns the track now on, if known.
  Future<AudioTrack?> _selectAudioTrack(String lang) async {
    final tracks = _playable(player.state.tracks.audio);
    final current = player.state.track.audio;

    final match = trackInLanguage(tracks, lang) as AudioTrack?;
    if (match != null) {
      if (current.id != match.id) await player.setAudioTrack(match);
      return match;
    }

    // Fallback: select first real track if still on 'auto'
    if (current.id == 'auto') {
      final firstReal = tracks.where(isRealTrack).firstOrNull;
      if (firstReal != null) await player.setAudioTrack(firstReal);
      return firstReal;
    }
    return current;
  }

  SubtitleKind Function(dynamic) get _kindOf => subtitleKindOf(_flagged);

  /// Selects the full (else CC) subtitles in [lang], never forced ones.
  /// Returns `true` if matched.
  Future<bool> _selectSubtitleTrack(String lang) async {
    final tracks = player.state.tracks.subtitle;
    final current = player.state.track.subtitle;

    final match = subtitleInLanguage(tracks, lang, _kindOf) as SubtitleTrack?;
    if (match != null) {
      if (current.id != match.id) await player.setSubtitleTrack(match);
      return true;
    }

    // Fallback: select first real track if still on 'auto'
    if (current.id == 'auto') {
      final firstReal =
          autoPickedSubtitle(tracks, lang, _kindOf) as SubtitleTrack?;
      if (firstReal != null) {
        await player.setSubtitleTrack(firstReal);
      }
    }

    return false;
  }

  /// With subtitles off: the forced subtitles for the sound now on ([audio],
  /// else [audioLang]), which only show what that sound doesn't say; none
  /// when the file has no such track.
  Future<void> _showForcedSubtitlesOnly(
    AudioTrack? audio,
    String audioLang,
  ) async {
    final soundLanguage = (audio?.language ?? '').trim().isNotEmpty
        ? audio!.language!
        : audioLang;
    final forced =
        forcedSubtitleFor(player.state.tracks.subtitle, soundLanguage, _kindOf)
            as SubtitleTrack?;
    if (forced == null) return _disableSubtitles();
    if (player.state.track.subtitle.id != forced.id) {
      await player.setSubtitleTrack(forced);
    }
  }

  /// Reads the file's forced / hearing impaired flags once per track list.
  /// Without them (an engine error) the titles' words still decide.
  Future<void> _readSubtitleFlags() async {
    final ids = player.state.tracks.subtitle
        .where(isRealTrack)
        .map((t) => t.id)
        .join(',');
    if (ids == _flagsReadFor) return;
    _flagsReadFor = ids;
    try {
      final platform = player.platform as dynamic;
      _flagged = await readSubtitleFlags(
        (property) async => await platform.getProperty(property) as String,
      );
    } catch (e, st) {
      AppLogger.warn(
        'TrackManager',
        'Could not read the subtitle flags',
        error: e,
        stackTrace: st,
      );
      _flagged = const {};
    }
    if (!ref.mounted) return; // the player closed meanwhile
    ref.read(subtitleFlagsProvider(subtitlesKey).notifier).set(_flagged);
  }

  /// Disables subtitles by selecting the 'no' track.
  Future<void> _disableSubtitles() async {
    if (player.state.track.subtitle.id == 'no') return;
    final noTrack = player.state.tracks.subtitle
        .where((t) => t.id == 'no')
        .firstOrNull;
    if (noTrack != null) await player.setSubtitleTrack(noTrack);
  }

  // ---------------------------------------------------------------------------
  // External subtitles
  // ---------------------------------------------------------------------------

  /// Fetches external subtitles (preferred language + English) and caches them
  /// in [externalSubtitlesProvider] for both auto-apply and UI consumption.
  Future<void> _fetchAndCacheExternalSubtitles() async {
    final service = ref.read(subtitleServiceProvider);
    if (!service.hasActiveProviders) {
      _setExternalSubsState(const AsyncValue.data([]));
      return;
    }

    final settings = ref.read(settingsProvider);
    final subLang = preferredSubtitleLanguage(
      settings,
      isAnime: _isAnime ?? false,
    );
    final searchLangs = subLang == 'en' ? 'en' : '$subLang,en';

    try {
      final queryId = params.queryId;
      final results = await service.search(
        imdbId: queryId.startsWith('tt') ? queryId : null,
        tmdbId: !queryId.startsWith('tt') ? queryId : null,
        season: params.season,
        episode: params.episode,
        language: searchLangs,
      );
      _setExternalSubsState(AsyncValue.data(results));
    } catch (e, st) {
      AppLogger.warn(
        'TrackManager',
        'External subtitle search failed',
        error: e,
        stackTrace: st,
      );
      _setExternalSubsState(AsyncValue.error(e, st));
    }
  }

  /// Auto-applies the best-matching external subtitle from cached results.
  Future<void> _autoApplyBestExternalSubtitle(String subLang) async {
    if (!ref.read(settingsProvider).autoDownloadMissingSubtitles) return;

    final results = await _awaitCachedExternalSubtitles();
    if (results == null || results.isEmpty) return;

    final bestMatch = _findBestExternalMatch(results, subLang) ?? results.first;

    try {
      final downloadUrl = await ref
          .read(subtitleServiceProvider)
          .getDownloadUrl(bestMatch);
      if (downloadUrl == null || downloadUrl.isEmpty) return;
      if (_isSubtitleAlreadyLoaded(downloadUrl)) return;

      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          downloadUrl,
          title: bestMatch.title,
          language: bestMatch.language,
        ),
      );
    } catch (e, s) {
      // Automatic: the user can still pick a subtitle in the panel.
      AppLogger.warn(
        'TrackManager',
        'Failed to download or apply external subtitle track: ${bestMatch.title}',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Waits up to 3 seconds for the external subtitles cache to be populated.
  Future<List<ExternalSubtitle>?> _awaitCachedExternalSubtitles() async {
    var cached = ref.read(externalSubtitlesProvider(subtitlesKey));
    if (cached is AsyncData<List<ExternalSubtitle>>) return cached.value;

    await Future.delayed(const Duration(seconds: 3));
    if (!ref.mounted) return null; // the player closed meanwhile
    cached = ref.read(externalSubtitlesProvider(subtitlesKey));
    return (cached is AsyncData<List<ExternalSubtitle>>) ? cached.value : null;
  }

  /// Finds the best external subtitle matching the preferred language.
  ExternalSubtitle? _findBestExternalMatch(
    List<ExternalSubtitle> subs,
    String lang,
  ) {
    final codes = LanguageMapper.getCodes(lang);
    return subs.cast<ExternalSubtitle?>().firstWhere(
      (s) => codes.any((code) => s!.language.toLowerCase() == code),
      orElse: () => null,
    );
  }

  bool _isSubtitleAlreadyLoaded(String url) =>
      player.state.tracks.subtitle.any((t) => t.id == url);

  void _setExternalSubsState(AsyncValue<List<ExternalSubtitle>> value) {
    // The search can end after the player closed: nobody to tell then.
    if (!ref.mounted) return;
    ref
        .read(externalSubtitlesProvider(subtitlesKey).notifier)
        .setResults(value);
  }
}
