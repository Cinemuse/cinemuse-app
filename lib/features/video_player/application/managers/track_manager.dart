import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/subtitle_service.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/external_subtitle.dart';
import 'package:media_kit/media_kit.dart';

/// Shared provider for external subtitle search results.
/// Populated by [TrackManager], consumed by the UI.
final externalSubtitlesProvider = StateProvider.family<AsyncValue<List<ExternalSubtitle>>, PlayerParams>(
  (ref, params) => const AsyncValue.loading(),
);

/// Manages automatic track (audio & subtitle) selection based on user preferences.
///
/// Reactively listens to [player.stream.tracks] and selects the preferred tracks
/// whenever the track list changes (e.g., after demuxing or external subtitle injection).
/// Also handles background fetching of external subtitles and auto-applying the best match.
class TrackManager extends BaseManager {
  final PlayerParams params;
  
  TrackManager({required super.ref, required super.player, required this.params}) {
    _tracksSubscription = player.stream.tracks.listen((_) => _onTracksChanged());
  }

  StreamSubscription? _tracksSubscription;
  bool _isAutoSelecting = true;
  bool _isPerformingSelection = false;
  bool _hasFetchedExternal = false;
  bool? _isAnime;
  Timer? _autoSelectTimeout;

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _autoSelectTimeout?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Disables auto-selection. Called by UI when user manually changes a track.
  void setManualSelection() {
    _isAutoSelecting = false;
    _autoSelectTimeout?.cancel();
  }

  /// Sets MPV engine properties (`alang`, `slang`) for instant track matching.
  void applyEnginePreferences({bool isAnime = false}) {
    final settings = ref.read(settingsProvider);
    final audioLang = _preferredAudioLang(settings, isAnime);
    final subLang = _preferredSubLang(settings, isAnime);
    if (audioLang.isEmpty) return;

    try {
      final audioCodes = LanguageMapper.getCodes(audioLang).join(',');
      final subCodes = LanguageMapper.getCodes(subLang).join(',');
      (player.platform as dynamic).setProperty('alang', audioCodes);
      (player.platform as dynamic).setProperty('slang', subCodes);
    } catch (_) {}
  }

  /// Enables reactive track selection once `isAnime` is known.
  /// Checks existing tracks immediately and fetches external subtitles in background.
  Future<void> ensurePreferredTrack({bool isAnime = false}) async {
    _isAnime = isAnime;
    _isAutoSelecting = true;
    _hasFetchedExternal = false;

    if (_preferredAudioLang(ref.read(settingsProvider), isAnime).isEmpty) return;

    _startAutoSelectTimeout();
    unawaited(_fetchAndCacheExternalSubtitles());

    if (_hasRealTracks()) {
      await _performSelection();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings helpers
  // ---------------------------------------------------------------------------

  String _preferredAudioLang(UserSettings s, bool isAnime) =>
      (s.splitAnimePreferences && isAnime) ? s.animeAudioLanguage.toLowerCase() : s.playerLanguage.toLowerCase();

  String _preferredSubLang(UserSettings s, bool isAnime) =>
      (s.splitAnimePreferences && isAnime) ? s.animeSubtitleLanguage.toLowerCase() : s.subtitleLanguage.toLowerCase();

  bool _preferredShowSubs(UserSettings s, bool isAnime) =>
      (s.splitAnimePreferences && isAnime) ? s.animeShowSubtitles : s.showSubtitles;

  // ---------------------------------------------------------------------------
  // Track selection
  // ---------------------------------------------------------------------------

  bool _hasRealTracks() => player.state.tracks.audio.any((t) => t.id != 'auto' && t.id != 'no');

  void _startAutoSelectTimeout() {
    _autoSelectTimeout?.cancel();
    _autoSelectTimeout = Timer(const Duration(seconds: 20), () => _isAutoSelecting = false);
  }

  void _onTracksChanged() {
    if (!_isAutoSelecting || _isAnime == null || _isPerformingSelection || !_hasRealTracks()) return;
    _performSelection();
  }

  Future<void> _performSelection() async {
    if (_isPerformingSelection) return;
    _isPerformingSelection = true;

    try {
      final settings = ref.read(settingsProvider);
      final isAnime = _isAnime ?? false;
      final audioLang = _preferredAudioLang(settings, isAnime);
      final subLang = _preferredSubLang(settings, isAnime);
      final showSubs = _preferredShowSubs(settings, isAnime);
      if (audioLang.isEmpty) return;

      await _selectAudioTrack(audioLang);

      if (!showSubs) {
        await _disableSubtitles();
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

  /// Selects the first audio track matching [lang], or falls back to the first real track.
  Future<void> _selectAudioTrack(String lang) async {
    final tracks = player.state.tracks.audio;
    final current = player.state.track.audio;

    final match = _findMatchingTrack(tracks, lang);
    if (match != null) {
      if (current.id != match.id) await player.setAudioTrack(match);
      return;
    }

    // Fallback: select first real track if still on 'auto'
    if (current.id == 'auto') {
      final firstReal = tracks.where((t) => t.id != 'auto' && t.id != 'no').firstOrNull;
      if (firstReal != null) await player.setAudioTrack(firstReal);
    }
  }

  /// Selects the first subtitle track matching [lang]. Returns `true` if matched.
  Future<bool> _selectSubtitleTrack(String lang) async {
    final tracks = player.state.tracks.subtitle;
    final current = player.state.track.subtitle;

    final match = _findMatchingTrack(tracks, lang);
    if (match != null) {
      if (current.id != match.id) await player.setSubtitleTrack(match as SubtitleTrack);
      return true;
    }

    // Fallback: select first real track if still on 'auto'
    if (current.id == 'auto') {
      final firstReal = tracks.where((t) => t.id != 'auto' && t.id != 'no').firstOrNull;
      if (firstReal != null) await player.setSubtitleTrack(firstReal);
    }

    return false;
  }

  /// Disables subtitles by selecting the 'no' track.
  Future<void> _disableSubtitles() async {
    if (player.state.track.subtitle.id == 'no') return;
    final noTrack = player.state.tracks.subtitle.where((t) => t.id == 'no').firstOrNull;
    if (noTrack != null) await player.setSubtitleTrack(noTrack);
  }

  /// Finds the first track in [tracks] whose language matches [lang].
  dynamic _findMatchingTrack(List<dynamic> tracks, String lang) {
    for (var track in tracks) {
      if (track.id == 'auto' || track.id == 'no') continue;
      if (LanguageMapper.isMatch(track, lang)) return track;
    }
    return null;
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
    final subLang = _preferredSubLang(settings, _isAnime ?? false);
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
    } catch (e) {
      _setExternalSubsState(AsyncValue.error(e, StackTrace.current));
    }
  }

  /// Auto-applies the best-matching external subtitle from cached results.
  Future<void> _autoApplyBestExternalSubtitle(String subLang) async {
    if (!ref.read(settingsProvider).autoDownloadMissingSubtitles) return;

    final results = await _awaitCachedExternalSubtitles();
    if (results == null || results.isEmpty) return;

    final bestMatch = _findBestExternalMatch(results, subLang) ?? results.first;

    try {
      final downloadUrl = await ref.read(subtitleServiceProvider).getDownloadUrl(bestMatch);
      if (downloadUrl == null || downloadUrl.isEmpty) return;
      if (_isSubtitleAlreadyLoaded(downloadUrl)) return;

      await player.setSubtitleTrack(SubtitleTrack.uri(
        downloadUrl,
        title: bestMatch.title,
        language: bestMatch.language,
      ));
    } catch (_) {}
  }

  /// Waits up to 3 seconds for the external subtitles cache to be populated.
  Future<List<ExternalSubtitle>?> _awaitCachedExternalSubtitles() async {
    var cached = ref.read(externalSubtitlesProvider(params));
    if (cached is AsyncData<List<ExternalSubtitle>>) return cached.value;

    await Future.delayed(const Duration(seconds: 3));
    cached = ref.read(externalSubtitlesProvider(params));
    return (cached is AsyncData<List<ExternalSubtitle>>) ? cached.value : null;
  }

  /// Finds the best external subtitle matching the preferred language.
  ExternalSubtitle? _findBestExternalMatch(List<ExternalSubtitle> subs, String lang) {
    final codes = LanguageMapper.getCodes(lang);
    return subs.cast<ExternalSubtitle?>().firstWhere(
      (s) => codes.any((code) => s!.language.toLowerCase() == code),
      orElse: () => null,
    );
  }

  bool _isSubtitleAlreadyLoaded(String url) =>
      player.state.tracks.subtitle.any((t) => t.id == url);

  void _setExternalSubsState(AsyncValue<List<ExternalSubtitle>> value) =>
      ref.read(externalSubtitlesProvider(params).notifier).state = value;
}
