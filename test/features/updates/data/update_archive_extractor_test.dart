import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/update_archive_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late String outputPath;

  setUp(() {
    root = Directory.systemTemp.createTempSync('update_extractor_test');
    outputPath = p.join(root.path, 'out');
  });

  tearDown(() => root.deleteSync(recursive: true));

  String writeZip(Map<String, String> files) {
    final archive = Archive();
    files.forEach(
      (name, text) => archive.addFile(ArchiveFile.string(name, text)),
    );
    final zipPath = p.join(root.path, 'update.zip');
    File(zipPath).writeAsBytesSync(ZipEncoder().encode(archive)!);
    return zipPath;
  }

  test('extracts files and subfolders', () async {
    final zip = writeZip({'cinemuse.exe': 'exe', 'data/app.so': 'lib'});

    await extractUpdateArchive(zip, outputPath);

    expect(File(p.join(outputPath, 'cinemuse.exe')).readAsStringSync(), 'exe');
    expect(
      File(p.join(outputPath, 'data', 'app.so')).readAsStringSync(),
      'lib',
    );
  });

  test('accepts Windows separators inside the folder', () async {
    final zip = writeZip({'data\\flutter_assets\\a.txt': 'a'});

    await extractUpdateArchive(zip, outputPath);

    final file = File(p.join(outputPath, 'data', 'flutter_assets', 'a.txt'));
    expect(file.readAsStringSync(), 'a');
  });

  for (final evilName in [
    '../evil.txt',
    '..\\evil.txt',
    'data/../../evil.txt',
    '/evil.txt',
    'C:\\evil.txt',
  ]) {
    test('refuses an entry outside the folder: $evilName', () async {
      final zip = writeZip({'cinemuse.exe': 'exe', evilName: 'evil'});

      await expectLater(
        extractUpdateArchive(zip, outputPath),
        throwsA(isA<ValidationFailure>()),
      );
      expect(File(p.join(root.path, 'evil.txt')).existsSync(), isFalse);
      // Nothing is written when one entry is bad.
      expect(File(p.join(outputPath, 'cinemuse.exe')).existsSync(), isFalse);
    });
  }

  test('replaces what an earlier failed extraction left', () async {
    File(p.join(outputPath, 'old.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    final zip = writeZip({'cinemuse.exe': 'exe'});

    await extractUpdateArchive(zip, outputPath);

    expect(File(p.join(outputPath, 'old.txt')).existsSync(), isFalse);
  });
}
