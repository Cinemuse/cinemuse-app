import 'package:path/path.dart' as p;
import 'package:cinemuse_app/core/error/app_failure.dart';

/// What a playlist and a guide share: a link or a copied file, turned on or
/// off, listed after the built-in one.
abstract class LiveTvSource {
  String get id;
  String get name;

  /// A link, or a local copy's file name.
  String get urlOrPath;
  bool get isLocal;
  bool get isEnabled;

  /// The Cinemuse one: always in the list, never saved with the user's own,
  /// only turned off.
  bool get isBuiltIn;

  String encode();

  /// What the UI shows under the name: the file name, or only the site of a
  /// URL, since IPTV URLs often hold `username=…&password=…` (REV-137).
  static String displaySourceOf(LiveTvSource source) => source.isLocal
      ? p.basename(source.urlOrPath)
      : Uri.tryParse(source.urlOrPath)?.host ?? '';
}

/// Why a playlist or guide that is on could not be read on its last load.
class LiveTvSourceFailure {
  final AppFailure failure;

  /// A downloaded playlist or a guide that failed but still shows its saved
  /// copy.
  final bool usesSavedCopy;

  const LiveTvSourceFailure(this.failure, {this.usesSavedCopy = false});
}

/// One load of the playlists or the guides: [data] from the ones that worked,
/// and the failed ones by id. One broken source never hides the others, and
/// is still shown as broken.
class LiveTvLoad<T> {
  final T data;
  final Map<String, LiveTvSourceFailure> failures;

  const LiveTvLoad(this.data, {this.failures = const {}});
}
