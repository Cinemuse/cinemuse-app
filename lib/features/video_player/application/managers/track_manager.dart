import 'dart:async';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/subtitles/subtitle_service.dart';
import 'package:media_kit/media_kit.dart';

/// Manages automatic track (audio & subtitle) selection based on user preferences.
///
/// Reactively listens to [player.stream.tracks] and selects the preferred tracks
/// whenever the track list changes (e.g., after demuxing or external subtitle injection).
/// Also handles auto-fetching external subtitles when no internal match is found.
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

  /// Called by UI when user manually changes a track.
  /// Disables auto-selection to prevent overriding the user's choice.
  void setManualSelection() {
    _isAutoSelecting = false;
    _autoSelectTimeout?.cancel();
  }

  /// Sets the MPV engine properties (`alang`, `slang`) for instant matching.
  void applyEnginePreferences({bool isAnime = false}) {
    final settings = ref.read(settingsProvider);
    final audioLang = _getAudioLang(settings, isAnime);
    final subLang = _getSubLang(settings, isAnime);

    if (audioLang.isEmpty) return;

    final codesJoined = LanguageMapper.getCodes(audioLang).join(',');
    final subCodesJoined = LanguageMapper.getCodes(subLang).join(',');

    try {
      (player.platform as dynamic).setProperty('alang', codesJoined);
      (player.platform as dynamic).setProperty('slang', subCodesJoined);
    } catch (_) {}
  }

  /// Called by PlayerController once `isAnime` is known.
  /// Enables reactive track selection via [_onTracksChanged].
  /// If tracks are already available, performs selection immediately.
  Future<void> ensurePreferredTrack({bool isAnime = false}) async {
    _isAnime = isAnime;
    _isAutoSelecting = true;
    _hasFetchedExternal = false;

    final settings = ref.read(settingsProvider);
    final audioLang = _getAudioLang(settings, isAnime);
    if (audioLang.isEmpty) return;
    
    // Safety timeout: stop auto-selecting after 20 seconds
    _autoSelectTimeout?.cancel();
    _autoSelectTimeout = Timer(const Duration(seconds: 20), () {
      _isAutoSelecting = false;
    });

    // Check if tracks are already available (they may have been emitted before this call)
    final hasRealTracks = player.state.tracks.audio.any(
      (t) => t.id != 'auto' && t.id != 'no',
    );
    
    if (hasRealTracks) {
      await _performSelection();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings helpers
  // ---------------------------------------------------------------------------

  String _getAudioLang(UserSettings settings, bool isAnime) {
    return (settings.splitAnimePreferences && isAnime) 
        ? settings.animeAudioLanguage.toLowerCase() 
        : settings.playerLanguage.toLowerCase();
  }

  String _getSubLang(UserSettings settings, bool isAnime) {
    return (settings.splitAnimePreferences && isAnime)
        ? settings.animeSubtitleLanguage.toLowerCase()
        : settings.subtitleLanguage.toLowerCase();
  }

  bool _getShowSubs(UserSettings settings, bool isAnime) {
    return (settings.splitAnimePreferences && isAnime)
        ? settings.animeShowSubtitles
        : settings.showSubtitles;
  }

  // ---------------------------------------------------------------------------
  // Reactive track selection
  // ---------------------------------------------------------------------------

  void _onTracksChanged() {
    if (!_isAutoSelecting) return;
    if (_isAnime == null) return;
    if (_isPerformingSelection) return;
    
    final hasRealTracks = player.state.tracks.audio.any(
      (t) => t.id != 'auto' && t.id != 'no',
    );
    if (!hasRealTracks) return;

    _performSelection();
  }

  Future<void> _performSelection() async {
    if (_isPerformingSelection) return;
    _isPerformingSelection = true;

    try {
      final settings = ref.read(settingsProvider);
      final isAnime = _isAnime ?? false;
      final audioLang = _getAudioLang(settings, isAnime);
      final subLang = _getSubLang(settings, isAnime);
      final showSubs = _getShowSubs(settings, isAnime);
      final tracks = player.state.tracks;

      if (audioLang.isEmpty) return;
     
      // 1. Audio Selection
      bool audioMatched = false;
      for (var track in tracks.audio) {
        if (track.id == 'auto' || track.id == 'no') continue;
        if (LanguageMapper.isMatch(track, audioLang)) {
          if (player.state.track.audio.id != track.id) {
            await player.setAudioTrack(track);
          }
          audioMatched = true;
          break;
        }
      }

      // Fallback: select first real audio track if still on 'auto'
      if (!audioMatched && player.state.track.audio.id == 'auto') {
        final firstReal = tracks.audio.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no', 
          orElse: () => player.state.track.audio,
        );
        if (firstReal.id != 'auto') {
          await player.setAudioTrack(firstReal);
        }
      }

      // 2. Subtitle Selection
      if (!showSubs) {
        if (player.state.track.subtitle.id != 'no') {
          final noTrack = tracks.subtitle.firstWhere(
            (t) => t.id == 'no',
            orElse: () => player.state.track.subtitle,
          );
          await player.setSubtitleTrack(noTrack);
        }
        return;
      }

      bool subtitleMatched = false;
      for (var track in tracks.subtitle) {
        if (track.id == 'auto' || track.id == 'no') continue;
        if (LanguageMapper.isMatch(track, subLang)) {
          if (player.state.track.subtitle.id != track.id) {
            await player.setSubtitleTrack(track);
          }
          subtitleMatched = true;
          break;
        }
      }
      
      // Fallback: select first real subtitle if still on 'auto'
      if (!subtitleMatched && player.state.track.subtitle.id == 'auto') {
        final firstReal = tracks.subtitle.firstWhere(
          (t) => t.id != 'auto' && t.id != 'no', 
          orElse: () => player.state.track.subtitle,
        );
        if (firstReal.id != 'auto') {
          await player.setSubtitleTrack(firstReal);
        }
      }
      
      // Auto-fetch external subtitles if no internal match was found
      if (!subtitleMatched && !_hasFetchedExternal) {
        _hasFetchedExternal = true;
        unawaited(_fetchExternalSubtitles(subLang));
      }
    } finally {
      _isPerformingSelection = false;
    }
  }

  // ---------------------------------------------------------------------------
  // External subtitle auto-fetch
  // ---------------------------------------------------------------------------

  Future<void> _fetchExternalSubtitles(String subLang) async {
    final settings = ref.read(settingsProvider);
    if (!settings.autoDownloadMissingSubtitles) return;
    
    final service = ref.read(subtitleServiceProvider);
    if (!service.hasActiveProviders) return;
    
    try {
      final queryId = params.queryId;
      final isImdb = queryId.startsWith('tt');
      
      final results = await service.search(
        imdbId: isImdb ? queryId : null,
        tmdbId: !isImdb ? queryId : null,
        season: params.season,
        episode: params.episode,
        language: subLang,
      );

      if (results.isNotEmpty) {
        final sub = results.first;
        final downloadUrl = await service.getDownloadUrl(sub);
         
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          // Avoid adding duplicates
          final alreadyPresent = player.state.tracks.subtitle.any(
            (t) => t.id == downloadUrl,
          );
          if (alreadyPresent) return;

          // sub-add will add the track to MPV's track list AND select it,
          // which triggers a track-list change → _onTracksChanged.
          // Re-entrant _performSelection is prevented by _isPerformingSelection guard,
          // and re-fetch is prevented by _hasFetchedExternal flag.
          final track = SubtitleTrack.uri(
            downloadUrl,
            title: sub.title,
            language: sub.language,
          );
          await player.setSubtitleTrack(track);
        }
      }
    } catch (_) {}
  }
}
