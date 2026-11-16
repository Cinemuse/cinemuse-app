import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the bytes of the image at a URL.
typedef FetchImageBytes = Future<Uint8List> Function(String url);

/// Opens the system "save as" window, which writes [bytes] to the chosen
/// place. Returns that path, or null if the user cancelled.
typedef SaveFileDialog =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
      required Uint8List bytes,
    });

// The image cache already holds the picture shown on screen, so this
// downloads only when it was evicted.
Future<Uint8List> _cachedImageBytes(String url) async {
  final file = await CachedNetworkImageProvider.defaultCacheManager
      .getSingleFile(url);
  return file.readAsBytes();
}

Future<String?> _filePickerSave({
  required String dialogTitle,
  required String fileName,
  required Uint8List bytes,
}) => FilePicker.saveFile(
  dialogTitle: dialogTitle,
  fileName: fileName,
  bytes: bytes,
);

/// Saves gallery images where the user picks.
class GalleryImageService {
  GalleryImageService({
    FetchImageBytes? fetchImageBytes,
    SaveFileDialog? saveFileDialog,
  }) : _fetchImageBytes = fetchImageBytes ?? _cachedImageBytes,
       _saveFileDialog = saveFileDialog ?? _filePickerSave;

  final FetchImageBytes _fetchImageBytes;
  final SaveFileDialog _saveFileDialog;

  // Same limit as the app's Dio receive timeout.
  static const _fetchTimeout = Duration(seconds: 30);

  /// Saves the image at [url] under its own file name. The bytes are read
  /// before the window opens because Android's save window needs them up
  /// front.
  ///
  /// Returns false if the user cancelled. Throws [NetworkFailure] if the
  /// image can't be fetched, [UnknownFailure] if it can't be saved.
  Future<bool> save(String url, {required String dialogTitle}) async {
    final Uint8List bytes;
    try {
      bytes = await _fetchImageBytes(url).timeout(_fetchTimeout);
    } catch (e, st) {
      throw NetworkFailure(
        'Gallery image fetch failed',
        cause: e,
        stackTrace: st,
      );
    }
    try {
      final path = await _saveFileDialog(
        dialogTitle: dialogTitle,
        fileName: _fileName(url),
        bytes: bytes,
      );
      return path != null;
    } catch (e, st) {
      throw UnknownFailure(
        'Gallery image save failed',
        cause: e,
        stackTrace: st,
      );
    }
  }

  static String _fileName(String url) {
    final segments = Uri.parse(url).pathSegments;
    return segments.isNotEmpty && segments.last.isNotEmpty
        ? segments.last
        : 'image.jpg';
  }
}

final galleryImageServiceProvider = Provider.autoDispose<GalleryImageService>(
  (ref) => GalleryImageService(),
);
