import 'package:cinemuse_app/features/media/data/gallery_image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Download" in the fullscreen gallery. The state is `true` while a save
/// runs, so the button shows a spinner and can't start a second one.
class GalleryImageSaveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Saves the image at [url] where the user picks. Returns false if the
  /// user cancelled or a save is already running. Throws an `AppFailure`.
  Future<bool> save(String url, {required String dialogTitle}) async {
    if (state) return false;
    state = true;
    try {
      return await ref
          .read(galleryImageServiceProvider)
          .save(url, dialogTitle: dialogTitle);
    } finally {
      state = false;
    }
  }
}

// Not autoDispose: the save window can outlive the viewer, and the flag must
// still clear when it ends.
final galleryImageSaveProvider =
    NotifierProvider<GalleryImageSaveNotifier, bool>(
      GalleryImageSaveNotifier.new,
    );
