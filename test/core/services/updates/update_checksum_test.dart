import 'dart:convert';
import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/updates/update_checksum.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late File zip;
  late String zipHash;

  setUp(() {
    root = Directory.systemTemp.createTempSync('update_checksum_test');
    zip = File(p.join(root.path, 'cinemuse-windows.zip'))
      ..writeAsStringSync('the real build');
    zipHash = sha256.convert(utf8.encode('the real build')).toString();
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('parseSha256Sums', () {
    test('reads text and binary mode lines, ignores the rest', () {
      final a = 'a' * 64;
      final b = 'B' * 64;
      final sums = parseSha256Sums(
        '$a  cinemuse-windows.zip\r\n$b *app-release.apk\n\nnot a line\n',
      );

      expect(sums, {'cinemuse-windows.zip': a, 'app-release.apk': 'b' * 64});
    });

    test('keeps only the file name when a folder is included', () {
      final sums = parseSha256Sums('${'c' * 64}  release-assets/x.zip');

      expect(sums.keys, ['x.zip']);
    });
  });

  group('verifyUpdateChecksum', () {
    test('accepts a file that matches', () async {
      await verifyUpdateChecksum(
        file: zip,
        assetName: 'cinemuse-windows.zip',
        sha256Sums: '${zipHash.toUpperCase()}  cinemuse-windows.zip\n',
      );
    });

    test('refuses a file that was changed', () async {
      zip.writeAsStringSync('a swapped build');

      await expectLater(
        verifyUpdateChecksum(
          file: zip,
          assetName: 'cinemuse-windows.zip',
          sha256Sums: '$zipHash  cinemuse-windows.zip\n',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('refuses a file with no line in SHA256SUMS', () async {
      await expectLater(
        verifyUpdateChecksum(
          file: zip,
          assetName: 'cinemuse-windows.zip',
          sha256Sums: '$zipHash  something-else.zip\n',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
