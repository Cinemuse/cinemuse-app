import 'dart:io';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lives for the whole session: the file is written once per run and every
/// player reuses it.
final certificateBundleFileProvider = FutureProvider<File>((ref) {
  return const CertificateBundleSource(
    loadAsset: _loadRootAsset,
    directory: getApplicationSupportDirectory,
  ).writeBundle();
});

Future<ByteData> _loadRootAsset(String key) => rootBundle.load(key);

/// Writes the app's list of trusted certificate authorities to a file the
/// player can read.
///
/// The player's TLS library (mbedtls in media_kit's Windows and Android
/// builds) can't read the system's trusted certificates: without this file it
/// either accepts any certificate or refuses them all.
class CertificateBundleSource {
  /// Mozilla's list, as published by curl (https://curl.se/docs/caextract.html).
  static const assetKey = 'assets/certs/cacert.pem';

  final Future<ByteData> Function(String key) _loadAsset;
  final Future<Directory> Function() _directory;

  const CertificateBundleSource({
    required Future<ByteData> Function(String key) loadAsset,
    required Future<Directory> Function() directory,
  }) : _loadAsset = loadAsset,
       _directory = directory;

  /// Copies the bundle into the directory and returns the file.
  /// Throws [StreamingFailure] if it can't be written.
  Future<File> writeBundle() async {
    final data = await _loadAsset(assetKey);
    try {
      final file = File(p.join((await _directory()).path, 'cacert.pem'));
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return file;
    } on FileSystemException catch (e, st) {
      throw StreamingFailure(
        'Could not write the certificate bundle',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
