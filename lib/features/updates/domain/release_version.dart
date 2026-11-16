/// A version like `1.3.2`, `v1.3.2+15` or `1.3.2-beta.1+15`.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  final int major;
  final int minor;
  final int patch;

  /// The part after `-` (`beta.1`), or `null` for a normal release.
  final String? preRelease;
  final int build;

  const ReleaseVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease,
    this.build = 0,
  });

  static final _pattern = RegExp(
    r'(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?',
  );

  /// Reads the first `x.y.z` in [text] (a leading `v` or other prefix is
  /// skipped). [build] wins over a `+build` part in [text]. Returns `null`
  /// when there is no `x.y.z`, instead of throwing (CI-05).
  static ReleaseVersion? tryParse(String text, {String? build}) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    return ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      preRelease: match.group(4),
      build: int.tryParse(build ?? match.group(5) ?? '') ?? 0,
    );
  }

  /// Orders by `x.y.z`, then a normal release after its pre-releases
  /// (`1.3.2-beta` < `1.3.2`), then by build number.
  @override
  int compareTo(ReleaseVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if ((preRelease == null) != (other.preRelease == null)) {
      return preRelease == null ? 1 : -1;
    }
    return build.compareTo(other.build);
  }
}

/// Whether the release [latestTag] is newer than the installed app
/// ([currentName] + [currentBuild] from `PackageInfo`). An unreadable
/// version never offers an update.
bool isNewerRelease(String latestTag, String currentName, String currentBuild) {
  final latest = ReleaseVersion.tryParse(latestTag);
  final current = ReleaseVersion.tryParse(currentName, build: currentBuild);
  if (latest == null || current == null) return false;
  return latest.compareTo(current) > 0;
}

/// Whether the installed app ([currentName] + [currentBuild] from
/// `PackageInfo`) is older than [minimum], the oldest version the database
/// still supports (REV-306). An unreadable version never blocks the app.
bool isBelowMinimumVersion(
  String minimum,
  String currentName,
  String currentBuild,
) {
  final min = ReleaseVersion.tryParse(minimum);
  final current = ReleaseVersion.tryParse(currentName, build: currentBuild);
  if (min == null || current == null) return false;
  return current.compareTo(min) < 0;
}
