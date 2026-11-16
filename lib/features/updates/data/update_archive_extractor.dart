import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:path/path.dart' as p;

/// Extracts the update at [archivePath] (a Windows ZIP or a Linux `.tar.gz`)
/// into [outputPath] on a background isolate, so the UI doesn't freeze
/// (PERF-03).
///
/// [outputPath] is deleted first. Throws a [ValidationFailure] when an entry
/// would land outside [outputPath] (zip-slip, SEC-03) or is a symbolic link:
/// a release built by CI never has those, so the file was tampered with and
/// the whole update is refused.
Future<void> extractUpdateArchive(String archivePath, String outputPath) {
  return Isolate.run(() => _extract(archivePath, outputPath));
}

Future<void> _extract(String archivePath, String outputPath) async {
  final outputDir = Directory(outputPath);
  if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
  outputDir.createSync(recursive: true);

  if (archivePath.endsWith('.tar.gz')) {
    await _extractTarGz(archivePath, outputPath);
    return;
  }
  final input = InputFileStream(archivePath);
  try {
    _writeEntries(ZipDecoder().decodeBuffer(input), outputPath);
  } finally {
    input.closeSync();
  }
}

/// The app is about 160 MB unpacked, so the `.tar` goes through a file next to
/// the download, not through memory. Dart's own `gzip`: the archive package's
/// took a minute and a half on a real build, with the app waiting on
/// "restarting".
Future<void> _extractTarGz(String archivePath, String outputPath) async {
  final tarPath = '$archivePath.tar';
  await File(
    archivePath,
  ).openRead().transform(gzip.decoder).pipe(File(tarPath).openWrite());

  final tarInput = InputFileStream(tarPath);
  try {
    _writeEntries(TarDecoder().decodeBuffer(tarInput), outputPath);
  } finally {
    tarInput.closeSync();
    File(tarPath).deleteSync();
  }
}

void _writeEntries(Archive archive, String outputPath) {
  // Check every entry before writing anything, so a bad file leaves nothing.
  final targets = [
    for (final entry in archive) (entry, safeEntryPath(outputPath, entry)),
  ];
  for (final (entry, target) in targets) {
    if (!entry.isFile) {
      Directory(target).createSync(recursive: true);
      continue;
    }
    File(target).parent.createSync(recursive: true);
    final output = OutputFileStream(target);
    try {
      entry.writeContent(output);
    } finally {
      output.closeSync();
    }
  }
}

/// The path where [entry] goes inside [outputPath].
///
/// ZIPs made on Windows can use `\` as separator, so both `\` and `/` count.
/// Throws a [ValidationFailure] for absolute paths, drive letters, `..`
/// segments and symbolic links.
String safeEntryPath(String outputPath, ArchiveFile entry) {
  final name = entry.name;
  if (entry.isSymbolicLink) {
    throw ValidationFailure('Update archive has a symbolic link: $name');
  }
  final segments = name.replaceAll('\\', '/').split('/');
  final isUnsafe =
      name.startsWith('/') ||
      name.startsWith('\\') ||
      name.contains(':') ||
      segments.contains('..');
  final target = p.joinAll([
    outputPath,
    ...segments.where((s) => s.isNotEmpty && s != '.'),
  ]);
  // A "./" folder entry is the output folder itself: harmless.
  final isOutputFolder = !entry.isFile && p.equals(outputPath, target);
  if (isUnsafe || !(isOutputFolder || p.isWithin(outputPath, target))) {
    throw ValidationFailure('Update archive entry escapes the folder: $name');
  }
  return target;
}
