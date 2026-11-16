import 'dart:io';
import 'dart:typed_data';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/gallery_image_service.dart';
import 'package:flutter_test/flutter_test.dart';

// REV-218: the viewer downloaded the original image again with its own Dio,
// and showed raw error text.
void main() {
  const url = 'https://image.tmdb.org/t/p/original/abc123.jpg';
  final imageBytes = Uint8List.fromList([1, 2, 3]);

  test('saves the fetched bytes under the URL file name', () async {
    final fetched = <String>[];
    ({String dialogTitle, String fileName, Uint8List bytes})? dialog;
    final service = GalleryImageService(
      fetchImageBytes: (u) async {
        fetched.add(u);
        return imageBytes;
      },
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) async {
            dialog = (
              dialogTitle: dialogTitle,
              fileName: fileName,
              bytes: bytes,
            );
            return r'C:\Pictures\abc123.jpg';
          },
    );

    expect(await service.save(url, dialogTitle: 'Download Image'), isTrue);
    expect(fetched, [url]);
    expect(dialog?.dialogTitle, 'Download Image');
    expect(dialog?.fileName, 'abc123.jpg');
    expect(identical(dialog?.bytes, imageBytes), isTrue);
  });

  test('a cancelled save window returns false', () async {
    final service = GalleryImageService(
      fetchImageBytes: (_) async => imageBytes,
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) async =>
              null,
    );

    expect(await service.save(url, dialogTitle: 'x'), isFalse);
  });

  test('a URL without a file name saves as image.jpg', () async {
    final fileNames = <String>[];
    final service = GalleryImageService(
      fetchImageBytes: (_) async => imageBytes,
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) async {
            fileNames.add(fileName);
            return null;
          },
    );

    await service.save('https://example.com/', dialogTitle: 'x');
    expect(fileNames, ['image.jpg']);
  });

  test('a failed fetch throws a NetworkFailure, no window opens', () async {
    var isDialogOpened = false;
    final service = GalleryImageService(
      fetchImageBytes: (_) async => throw const SocketException('offline'),
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) async {
            isDialogOpened = true;
            return null;
          },
    );

    await expectLater(
      service.save(url, dialogTitle: 'x'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(isDialogOpened, isFalse);
  });

  test('a failed save throws an UnknownFailure', () async {
    final service = GalleryImageService(
      fetchImageBytes: (_) async => imageBytes,
      saveFileDialog:
          ({required dialogTitle, required fileName, required bytes}) async =>
              throw const FileSystemException('read-only'),
    );

    await expectLater(
      service.save(url, dialogTitle: 'x'),
      throwsA(isA<UnknownFailure>()),
    );
  });
}
