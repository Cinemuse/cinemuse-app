import 'package:cinemuse_app/features/updates/domain/release_version.dart';

/// One release's notes. The release's text has a `## English` and a
/// `## Italiano` part (CONTRIBUTING.md → CI and releases).
class ReleaseNotes {
  /// The version as the app shows it: the tag without its `v`.
  final String version;

  /// Each language's notes, by language code (`en`, `it`).
  final Map<String, String> byLanguage;

  const ReleaseNotes(this.version, this.byLanguage);

  static const _titles = {'english': 'en', 'italiano': 'it'};
  static final _title = RegExp(r'^##\s+(\S+)\s*$');

  /// Reads the release [tag]'s [body]; `null` when it has neither part
  /// (the releases up to 2.0, whose text GitHub wrote).
  static ReleaseNotes? tryParse(String tag, String? body) {
    if (body == null) return null;
    final parts = <String, StringBuffer>{};
    StringBuffer? current;
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final title = _title.firstMatch(line.trim())?.group(1)?.toLowerCase();
      final language = _titles[title];
      if (language != null) {
        current = parts[language] = StringBuffer();
      } else {
        current?.writeln(line);
      }
    }
    final byLanguage = {
      for (final MapEntry(:key, :value) in parts.entries)
        if (value.toString().trim().isNotEmpty) key: value.toString().trim(),
    };
    if (byLanguage.isEmpty) return null;
    return ReleaseNotes(tag.replaceFirst(RegExp('^v'), ''), byLanguage);
  }

  /// The notes in [languageCode], else in English, else whichever is there.
  String inLanguage(String languageCode) =>
      byLanguage[languageCode] ?? byLanguage['en'] ?? byLanguage.values.first;
}

/// The releases in GitHub's list newer than the installed app
/// ([currentName] + [currentBuild]), newest first. Test releases
/// (pre-releases) and drafts are skipped.
List<Map<String, dynamic>> newerReleases(
  List<dynamic> releases,
  String currentName,
  String currentBuild,
) {
  final newer = [
    for (final release in releases.cast<Map<String, dynamic>>())
      if (release['prerelease'] != true &&
          release['draft'] != true &&
          release['tag_name'] is String &&
          isNewerRelease(
            release['tag_name'] as String,
            currentName,
            currentBuild,
          ))
        release,
  ];
  ReleaseVersion versionOf(Map<String, dynamic> release) =>
      ReleaseVersion.tryParse(release['tag_name'] as String)!;
  newer.sort((a, b) => versionOf(b).compareTo(versionOf(a)));
  return newer;
}
