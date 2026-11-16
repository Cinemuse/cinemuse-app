import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/gallery_image_save_notifier.dart';
import 'package:cinemuse_app/features/media/data/gallery_image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

// REV-218: the download ran inside the viewer widget.
void main() {
  ProviderContainer containerWith(GalleryImageService service) {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [galleryImageServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('is busy while saving, and a second save is refused', () async {
    final window = Completer<String?>();
    var dialogCount = 0;
    final container = containerWith(
      GalleryImageService(
        fetchImageBytes: (_) async => Uint8List(1),
        saveFileDialog:
            ({required dialogTitle, required fileName, required bytes}) {
              dialogCount++;
              return window.future;
            },
      ),
    );
    final saver = container.read(galleryImageSaveProvider.notifier);

    final first = saver.save('https://example.com/a.jpg', dialogTitle: 'x');
    expect(container.read(galleryImageSaveProvider), isTrue);
    expect(
      await saver.save('https://example.com/a.jpg', dialogTitle: 'x'),
      isFalse,
    );

    window.complete('/home/me/a.jpg');
    expect(await first, isTrue);
    expect(dialogCount, 1);
    expect(container.read(galleryImageSaveProvider), isFalse);
  });

  test('a failure clears the busy flag and is rethrown', () async {
    final container = containerWith(
      GalleryImageService(
        fetchImageBytes: (_) async => throw const SocketException('offline'),
      ),
    );
    final saver = container.read(galleryImageSaveProvider.notifier);

    await expectLater(
      saver.save('https://example.com/a.jpg', dialogTitle: 'x'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(container.read(galleryImageSaveProvider), isFalse);
  });
}
