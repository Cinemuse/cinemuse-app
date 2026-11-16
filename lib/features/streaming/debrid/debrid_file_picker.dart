import 'package:cinemuse_app/core/utils/episode_parser.dart';

/// Picks the file to play in a debrid torrent. Shared by Real-Debrid and
/// TorBox (REV-28) so both choose the same way.
///
/// Files are the services' normalised maps: `id`, `path`, `bytes`.
class DebridFilePicker {
  static const _videoExtensions = [
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.m4v',
    '.webm',
    '.flv',
    '.wmv',
  ];

  static final _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]', unicode: true);

  static bool isVideo(String path) {
    final lower = path.toLowerCase();
    return _videoExtensions.any(lower.endsWith);
  }

  /// In order: the user's [fileId]; the add-on's [hintFileName]; the add-on's
  /// file index as the service's [hintFileId]; for a movie the largest file;
  /// for an episode the file whose name matches it; a lone file. Returns the
  /// file's id, or null when none of these finds it: no guess, a wrong
  /// episode is worse than none, so the player tries the next source
  /// (REV-318).
  static int? pick(
    List<Map<String, dynamic>> files, {
    int? fileId,
    String? hintFileName,
    int? hintFileId,
    int? season,
    int? episode,
    int? absoluteEpisode,
  }) {
    if (files.isEmpty) return null;
    if (fileId != null) return fileId;

    final byName = _byFileName(files, hintFileName);
    if (byName != null) return byName;

    if (hintFileId != null && files.any((f) => f['id'] == hintFileId)) {
      return hintFileId;
    }

    final largest = _largestId(files);
    if (season == null || episode == null) return largest;

    for (final f in files) {
      // The base name only: a folder like "Show.S01.COMPLETE" reads as a
      // batch, and a batch "matches" every episode.
      if (EpisodeParser.matches(
        _baseName(f['path'] as String),
        targetSeason: season,
        targetEpisode: episode,
        targetAbsoluteEpisode: absoluteEpisode,
      )) {
        return f['id'] as int;
      }
    }

    if (files.length == 1) return largest;
    return null;
  }

  /// Compares base names only, ignoring case and punctuation: services put
  /// the torrent folder in front, and TorBox rewrites some characters.
  static int? _byFileName(List<Map<String, dynamic>> files, String? name) {
    if (name == null || name.isEmpty) return null;
    final target = _normalise(name);
    if (target.isEmpty) return null;
    for (final f in files) {
      if (_normalise(f['path'] as String) == target) return f['id'] as int;
    }
    return null;
  }

  static final _pathSeparator = RegExp(r'[/\\]');

  static String _baseName(String path) => path.split(_pathSeparator).last;

  static String _normalise(String path) => _baseName(
    path,
  ).toLowerCase().replaceAll('&', 'and').replaceAll(_notLetterOrDigit, '');

  static int _largestId(List<Map<String, dynamic>> files) =>
      files.reduce(
            (a, b) => (b['bytes'] as int) > (a['bytes'] as int) ? b : a,
          )['id']
          as int;
}
