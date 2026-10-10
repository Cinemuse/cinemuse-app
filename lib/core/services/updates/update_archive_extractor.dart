import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:path/path.dart' as p;

/// Extracts the update ZIP at [zipPath] into [outputPath] on a background
/// isolate, so the UI doesn't freeze (PERF-03).
///
/// [outputPath] is deleted first. Throws a [ValidationFailure] when an entry
/// would land outside [outputPath] (zip-slip, SEC-03) or is a symbolic link:
/// a release built by CI never has those, so the file was tampered with and
/// the whole update is refused.
Future<void> extractUpdateArchive(String zipPath, String outputPath) {
  return Isolate.run(() => _extract(zipPath, outputPath));
}

void _extract(String zipPath, String outputPath) {
  final outputDir = Directory(outputPath);
  if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
  outputDir.createSync(recursive: true);

  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    // Check every entry before writing anything, so a bad ZIP leaves no files.
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
  } finally {
    input.closeSync();
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
