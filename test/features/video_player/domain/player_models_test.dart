import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pack\'s files are listed by file name, ignoring case', () {
    final files = StreamFileInfo.byName([
      {'id': 1, 'path': '/Show/S01E10.mkv', 'bytes': 1},
      {'id': 2, 'path': '/Show/extras/behind.mkv', 'bytes': 1},
      {'id': 3, 'path': '/Show/S01E02.mkv', 'bytes': 1},
    ]);

    expect(files.map((f) => f.filename), [
      'behind.mkv',
      'S01E02.mkv',
      'S01E10.mkv',
    ]);
  });
}
