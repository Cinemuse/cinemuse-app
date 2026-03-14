import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/application/managers/base_manager.dart';

class TrackManager extends BaseManager {
  TrackManager({required super.ref, required super.player});

  /// Toggle this for debugging track selection issues
  static const bool showLogs = false;

  /// Sets the engine properties for instant matching (based on codes).
  void applyEnginePreferences() {
    final lang = ref.read(settingsProvider).playerLanguage.toLowerCase();
    if (lang.isEmpty) return;

    final langCodes = LanguageMapper.getCodes(lang);
    final codesJoined = langCodes.join(',');

    try {
      (player.platform as dynamic).setProperty('alang', codesJoined);
      (player.platform as dynamic).setProperty('slang', codesJoined);
    } catch (e) {
      // silent engine preference set fail
    }
  }

  /// Ensures preferred tracks are selected, with a robust wait-and-verify mechanism.
  Future<void> ensurePreferredTrack() async {
    final lang = ref.read(settingsProvider).playerLanguage.toLowerCase();
    if (lang.isEmpty) return;

    try {
      // 1. Wait for tracks to be available (up to 5 seconds)
      await _waitForTracks();

      // 2. Initial selection logic
      await _performSelection(lang);

      // 3. Reliability Check: Secondary verify after a short delay
      // Sometimes player overrides selection during early buffering
      await Future.delayed(const Duration(milliseconds: 800));
      await _performSelection(lang, isVerify: true);

    } catch (e) {
      // ignore
    }
  }

  Future<void> _waitForTracks() async {
    // Wait until at least one audio track is present (excluding 'auto'/'no')
    await player.stream.tracks
        .firstWhere((t) => t.audio.any((at) => at.id != 'auto' && at.id != 'no'))
        .timeout(const Duration(seconds: 5));
        
    // Small delay to ensure metadata/titles are fully parsed by the engine
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (showLogs) _logAvailableTracks();
  }

  void _logAvailableTracks() {
    if (!showLogs) return;
    final tracks = player.state.tracks;
    debugPrint('--- Track Discovery ---');
    debugPrint('Audio Tracks (${tracks.audio.length}):');
    for (var t in tracks.audio) {
      debugPrint('  - [${t.id}] ${t.title} (Language: ${t.language})');
    }
    debugPrint('Subtitle Tracks (${tracks.subtitle.length}):');
    for (var t in tracks.subtitle) {
      debugPrint('  - [${t.id}] ${t.title} (Language: ${t.language})');
    }
    debugPrint('-----------------------');
  }

  Future<void> _performSelection(String lang, {bool isVerify = false}) async {
    final tracks = player.state.tracks;
    
    // 1. Audio Selection
    bool audioMatched = false;
    for (var track in tracks.audio) {
      if (track.id == 'auto' || track.id == 'no') continue;
      if (LanguageMapper.isMatch(track, lang)) {
        if (!isVerify || player.state.track.audio.id != track.id) {
          if (showLogs) debugPrint('  -> Selecting Audio: ${track.title} (${track.language}) ${isVerify ? "[Verify]" : ""}');
          await player.setAudioTrack(track);
        }
        audioMatched = true;
        break;
      }
    }

    // Fallback for audio if stuck on 'auto'
    if (!audioMatched && player.state.track.audio.id == 'auto') {
      final firstReal = tracks.audio.firstWhere(
        (t) => t.id != 'auto' && t.id != 'no', 
        orElse: () => player.state.track.audio
      );
      if (firstReal.id != 'auto') {
        if (showLogs) debugPrint('  -> Audio Fallback: ${firstReal.title}');
        await player.setAudioTrack(firstReal);
      }
    }

    // 2. Subtitle Selection
    bool subtitleMatched = false;
    for (var track in tracks.subtitle) {
      if (track.id == 'auto' || track.id == 'no') continue;
      if (LanguageMapper.isMatch(track, lang)) {
        if (!isVerify || player.state.track.subtitle.id != track.id) {
          if (showLogs) debugPrint('  -> Selecting Subtitle: ${track.title} (${track.language}) ${isVerify ? "[Verify]" : ""}');
          await player.setSubtitleTrack(track);
        }
        subtitleMatched = true;
        break;
      }
    }
    
    // Fallback for subtitles
    if (!subtitleMatched && player.state.track.subtitle.id == 'auto') {
      final firstReal = tracks.subtitle.firstWhere(
        (t) => t.id != 'auto' && t.id != 'no', 
        orElse: () => player.state.track.subtitle
      );
      if (firstReal.id != 'auto') {
        if (showLogs) debugPrint('  -> Subtitle Fallback: ${firstReal.title}');
        await player.setSubtitleTrack(firstReal);
      }
    }
  }
}
