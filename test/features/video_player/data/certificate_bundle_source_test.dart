import 'dart:io';
import 'dart:typed_data';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/video_player/data/certificate_bundle_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final bundleFile = File(CertificateBundleSource.assetKey);

  group('CertificateBundleSource.writeBundle', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('certificate_bundle_test');
    });
    tearDown(() => dir.delete(recursive: true));

    CertificateBundleSource sourceIn(Directory directory) =>
        CertificateBundleSource(
          loadAsset: (key) async =>
              ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4, 5]), 1, 4),
          directory: () async => directory,
        );

    test('copies the bundle into the directory and returns the file', () async {
      final file = await sourceIn(dir).writeBundle();

      expect(p.dirname(file.path), dir.path);
      expect(await file.readAsBytes(), [2, 3, 4]);
    });

    test('a directory it cannot write to is a StreamingFailure', () async {
      final missing = Directory(p.join(dir.path, 'missing'));

      expect(sourceIn(missing).writeBundle(), throwsA(isA<StreamingFailure>()));
    });
  });

  group('the shipped bundle', () {
    test('is a list of certificate authorities TLS can load', () {
      final text = bundleFile.readAsStringSync();

      expect(
        '-----BEGIN CERTIFICATE-----'.allMatches(text).length,
        greaterThan(100),
      );
      expect(
        () => SecurityContext(
          withTrustedRoots: false,
        ).setTrustedCertificates(bundleFile.path),
        returnsNormally,
      );
    });

    test('is less than a year old (refresh it from curl.se/ca/cacert.pem)', () {
      const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
      final match = RegExp(
        r'Mozilla as of: \w{3} (\w{3}) +(\d+) [\d:]+ (\d{4})',
      ).firstMatch(bundleFile.readAsStringSync())!;
      final date = DateTime.utc(
        int.parse(match[3]!),
        months.indexOf(match[1]!) ~/ 3 + 1,
        int.parse(match[2]!),
      );

      expect(DateTime.now().difference(date).inDays, lessThan(365));
    });
  });
}
