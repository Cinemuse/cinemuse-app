import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:media_kit/media_kit.dart';

/// The audio language the player picks by itself, lower case.
String preferredAudioLanguage(UserSettings s, {required bool isAnime}) =>
    (s.splitAnimePreferences && isAnime)
    ? s.animeAudioLanguage.toLowerCase()
    : s.playerLanguage.toLowerCase();

/// The subtitle language the player picks by itself, lower case.
String preferredSubtitleLanguage(UserSettings s, {required bool isAnime}) =>
    (s.splitAnimePreferences && isAnime)
    ? s.animeSubtitleLanguage.toLowerCase()
    : s.subtitleLanguage.toLowerCase();

/// False for the engine's own "auto" and "no" entries.
bool isRealTrack(dynamic track) => track.id != 'auto' && track.id != 'no';

/// The first real track in [language], or null.
dynamic trackInLanguage(List<dynamic> tracks, String language) {
  for (final track in tracks) {
    if (isRealTrack(track) && LanguageMapper.isMatch(track, language)) {
      return track;
    }
  }
  return null;
}

/// The track the player picks by itself: the first one in [language], else
/// the first real one. Null when there is no real track.
dynamic autoPickedTrack(List<dynamic> tracks, String language) =>
    trackInLanguage(tracks, language) ?? tracks.where(isRealTrack).firstOrNull;

/// What a file's sound tracks say of a language.
enum SoundLanguage {
  /// A sound track is in it.
  present,

  /// Every sound track names another language.
  missing,

  /// No sound track yet, or one names no language: it may be that one.
  unknown,
}

/// Whether [tracks], a file's sound tracks, hold [language]. A stream's name
/// can call subtitles "ITA"; only the file's own tracks know.
SoundLanguage soundLanguageOf(List<AudioTrack> tracks, String language) {
  final real = tracks.where(isRealTrack).toList();
  if (real.isEmpty || language.isEmpty) return SoundLanguage.unknown;
  if (trackInLanguage(real, language) != null) return SoundLanguage.present;
  return real.any((t) => LanguageMapper.trackLanguage(t) == null)
      ? SoundLanguage.unknown
      : SoundLanguage.missing;
}

/// How a subtitle track is read: [flagged] holds what the file itself says,
/// by track id (see `readSubtitleFlags`).
SubtitleKind Function(dynamic) subtitleKindOf(
  Map<String, SubtitleKind> flagged,
) =>
    (track) => LanguageMapper.subtitleKind(track, flagged: flagged[track.id]);

/// The subtitles in [language] the player turns on by themselves: the full
/// ones, else the CC ones; never the forced ones, which show only bits.
dynamic subtitleInLanguage(
  List<dynamic> tracks,
  String language,
  SubtitleKind Function(dynamic) kindOf,
) {
  final inLanguage = tracks
      .where((t) => isRealTrack(t) && LanguageMapper.isMatch(t, language))
      .toList();
  return inLanguage.where((t) => kindOf(t) == SubtitleKind.full).firstOrNull ??
      inLanguage.where((t) => kindOf(t) == SubtitleKind.cc).firstOrNull;
}

/// The subtitles the player picks by itself: [subtitleInLanguage], else the
/// first real track that isn't forced. Null when there is none.
dynamic autoPickedSubtitle(
  List<dynamic> tracks,
  String language,
  SubtitleKind Function(dynamic) kindOf,
) =>
    subtitleInLanguage(tracks, language, kindOf) ??
    tracks
        .where((t) => isRealTrack(t) && kindOf(t) != SubtitleKind.forced)
        .firstOrNull;

/// The forced subtitles for sound in [soundLanguage], shown with subtitles
/// off, or null.
dynamic forcedSubtitleFor(
  List<dynamic> tracks,
  String soundLanguage,
  SubtitleKind Function(dynamic) kindOf,
) => tracks
    .where(
      (t) =>
          isRealTrack(t) &&
          kindOf(t) == SubtitleKind.forced &&
          LanguageMapper.isMatch(t, soundLanguage),
    )
    .firstOrNull;

/// The track the player made of [link] (a subtitle added by its address),
/// once loaded: the newest real track with its name and language. Null
/// while it is still being fetched.
SubtitleTrack? loadedCopyOf(SubtitleTrack link, List<SubtitleTrack> tracks) =>
    tracks
        .where(
          (t) =>
              !t.uri &&
              isRealTrack(t) &&
              t.title == link.title &&
              t.language == link.language,
        )
        .lastOrNull;

/// The subtitles a stream lists without the player having loaded them
/// (some sources put them in the stream's metadata). One the player already
/// has, by name and language, is left out: another track in the same
/// language ("English" loaded, "English · CC" not) stays.
List<SubtitleTrack> onDemandSubtitleTracks(
  ResolvedStream? stream,
  List<SubtitleTrack> loaded,
) {
  final items = stream?.candidate.metadata?.custom?['onDemandSubtitles'];
  if (items is! List) return const [];
  final tracks = <SubtitleTrack>[];
  for (final item in items) {
    if (item is! Map) continue;
    final uri = item['uri'] as String?;
    if (uri == null || uri.isEmpty) continue;
    final track = SubtitleTrack.uri(
      uri,
      title: item['name'] as String?,
      language: item['language'] as String?,
    );
    if (loadedCopyOf(track, loaded) == null) tracks.add(track);
  }
  return tracks;
}

/// What the audio or subtitles panel lists, and which row is on.
class TrackChoices {
  /// The real tracks and (subtitles) the stream's on-demand ones, grouped by
  /// language (see [LanguageMapper.sortedByLanguage]).
  final List<dynamic> tracks;

  /// The "off" entry.
  final dynamic offTrack;

  /// The track that is on. On "auto", the one the player picks by itself,
  /// so the panel and its menu line name the track actually playing.
  final dynamic current;

  /// What each subtitle track holds; audio tracks are all full.
  final SubtitleKind Function(dynamic) kindOf;

  const TrackChoices._(this.tracks, this.offTrack, this.current, this.kindOf);

  factory TrackChoices.audio(CinemaPlayerState state, String language) {
    final player = state.controller.player.state;
    final real = player.tracks.audio.where(isRealTrack).toList();
    final selected = state.activeAudioTrack ?? player.track.audio;
    return TrackChoices._resolve(
      all: player.tracks.audio,
      extra: const [],
      // A sound added by its address (a YouTube video's separate sound) is
      // on as the track the player made of it: the newest one.
      current: selected.id == 'auto'
          ? autoPickedTrack(real, language) ?? selected
          : selected.uri
          ? real.lastOrNull ?? selected
          : selected,
      fallbackOff: AudioTrack.no(),
      kindOf: (_) => SubtitleKind.full,
    );
  }

  /// [flagged]: the subtitles the file marks as forced or CC, by track id.
  factory TrackChoices.subtitles(
    CinemaPlayerState state,
    String language, {
    Map<String, SubtitleKind> flagged = const {},
  }) {
    final player = state.controller.player.state;
    final all = player.tracks.subtitle;
    final real = all.where(isRealTrack).toList();
    final selected = state.activeSubtitleTrack ?? player.track.subtitle;
    final kindOf = subtitleKindOf(flagged);
    return TrackChoices._resolve(
      all: all,
      extra: onDemandSubtitleTracks(state.currentStream, real),
      // Only the loaded tracks: the player never picks an on-demand one.
      // One added by its address is on as the track the player made of it.
      // With no subtitles at all (a YouTube trailer), none show: "off".
      current: selected.id == 'auto'
          ? autoPickedSubtitle(real, language, kindOf) ??
                (real.isEmpty ? SubtitleTrack.no() : selected)
          : selected.uri
          ? loadedCopyOf(selected, real) ?? selected
          : selected,
      fallbackOff: SubtitleTrack.no(),
      kindOf: kindOf,
    );
  }

  factory TrackChoices._resolve({
    required List<dynamic> all,
    required List<dynamic> extra,
    required dynamic current,
    required dynamic fallbackOff,
    required SubtitleKind Function(dynamic) kindOf,
  }) {
    return TrackChoices._(
      LanguageMapper.sortedByLanguage<dynamic>([
        ...all.where(isRealTrack),
        ...extra,
      ], kindOf),
      all.where((t) => t.id == 'no').firstOrNull ?? fallbackOff,
      current,
      kindOf,
    );
  }

  bool get isOff => current.id == 'no';

  /// By id: two tracks may share a title (e.g. two "English" subtitles, full
  /// and SDH), and both looked selected (REV-169). The title counts only for
  /// on-demand subtitle entries, whose id is their URI.
  bool isOn(dynamic track) =>
      current.id == track.id ||
      (track is SubtitleTrack &&
          track.uri &&
          track.title != null &&
          current.title == track.title);
}
