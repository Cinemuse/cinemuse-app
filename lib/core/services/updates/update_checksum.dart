import 'dart:io';
import 'dart:isolate';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Name of the checksum file that the release workflow publishes next to
/// the build files (CI-03).
const sha256SumsAssetName = 'SHA256SUMS';

/// Checks that [file] matches its line in [sha256Sums] (the text of the
/// release's `SHA256SUMS`, in `sha256sum` format) under the name [assetName].
///
/// Throws a [ValidationFailure] when the file has no line or the hash differs:
/// the download is broken or was swapped, so it must not be installed (SEC-03).
Future<void> verifyUpdateChecksum({
  required File file,
  required String assetName,
  required String sha256Sums,
}) async {
  final expected = parseSha256Sums(sha256Sums)[assetName];
  if (expected == null) {
    throw ValidationFailure('$sha256SumsAssetName has no line for $assetName');
  }
  final path = file.path;
  final actual = await Isolate.run(
    () async => (await sha256.bind(File(path).openRead()).first).toString(),
  );
  if (actual != expected) {
    throw ValidationFailure(
      'Checksum mismatch for $assetName: expected $expected, got $actual',
    );
  }
}

/// File name → lower-case hex hash, from `sha256sum` output.
///
/// Accepts `<hash>  <name>` and binary mode `<hash> *<name>`; a name with a
/// folder (`release-assets/x.zip`) counts as its file name only.
Map<String, String> parseSha256Sums(String text) {
  final line = RegExp(r'^([0-9a-fA-F]{64}) [ *](.+)$');
  return {
    for (final match in text.split('\n').map((l) => line.firstMatch(l.trim())))
      if (match != null)
        p.posix.basename(match.group(2)!.replaceAll('\\', '/')): match
            .group(1)!
            .toLowerCase(),
  };
}
