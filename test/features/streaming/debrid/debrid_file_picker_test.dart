import 'package:cinemuse_app/features/streaming/debrid/debrid_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _file(int id, String path, [int bytes = 1000]) => {
  'id': id,
  'path': path,
  'bytes': bytes,
};

// A season pack with a sample and an extra, in a "COMPLETE" folder (it
// used to make every file match). Sorting by name puts them
// first, so the old "episode N = Nth file" guess played the wrong file.
final _pack = [
  _file(1, '/Show.S01.COMPLETE.1080p/Sample/sample.mkv', 10),
  _file(2, '/Show.S01.COMPLETE.1080p/Extras/Making Of.mkv', 500),
  _file(3, '/Show.S01.COMPLETE.1080p/Show.S01E01.1080p.mkv', 2000),
  _file(4, '/Show.S01.COMPLETE.1080p/Show.S01E02.1080p.mkv', 2100),
  _file(5, '/Show.S01.COMPLETE.1080p/Show.S01E03.1080p.mkv', 1900),
];

// Episode files whose names carry no episode number.
final _unnamed = [
  _file(1, '/Pack/aaa.mkv', 2000),
  _file(2, '/Pack/bbb.mkv', 2200),
  _file(3, '/Pack/ccc.mkv', 2100),
];

void main() {
  group('DebridFilePicker.pick (STR-04, REV-28)', () {
    final cases =
        <
          ({
            String name,
            List<Map<String, dynamic>> files,
            int? fileId,
            String? hintFileName,
            int? hintFileId,
            int? season,
            int? episode,
            int? expectedId,
          })
        >[
          (
            name: "the user's pick wins over everything",
            files: _pack,
            fileId: 5,
            hintFileName: 'Show.S01E01.1080p.mkv',
            hintFileId: 3,
            season: 1,
            episode: 1,
            expectedId: 5,
          ),
          (
            name:
                "the add-on's file name, ignoring folder, case and punctuation",
            files: _unnamed,
            fileId: null,
            hintFileName: 'BBB.mkv',
            hintFileId: null,
            season: 1,
            episode: 1,
            expectedId: 2,
          ),
          (
            name: "the add-on's file id when its name is not found",
            files: _unnamed,
            fileId: null,
            hintFileName: 'renamed.mkv',
            hintFileId: 3,
            season: 1,
            episode: 1,
            expectedId: 3,
          ),
          (
            name: 'a file id that is not in the list is ignored',
            files: _pack,
            fileId: null,
            hintFileName: null,
            hintFileId: 99,
            season: 1,
            episode: 2,
            expectedId: 4,
          ),
          (
            name: 'a movie plays the largest file',
            files: _pack,
            fileId: null,
            hintFileName: null,
            hintFileId: null,
            season: null,
            episode: null,
            expectedId: 4,
          ),
          (
            name: 'an episode plays the file named after it, not the Nth file',
            files: _pack,
            fileId: null,
            hintFileName: null,
            hintFileId: null,
            season: 1,
            episode: 1,
            expectedId: 3,
          ),
          (
            name: 'a lone file is not a guess',
            files: [_file(7, '/Show.S01.COMPLETE.1080p/aaa.mkv')],
            fileId: null,
            hintFileName: null,
            hintFileId: null,
            season: 1,
            episode: 4,
            expectedId: 7,
          ),
          (
            name: 'no match: no guess, nothing is picked (REV-318)',
            files: _unnamed,
            fileId: null,
            hintFileName: null,
            hintFileId: null,
            season: 1,
            episode: 3,
            expectedId: null,
          ),
        ];

    for (final c in cases) {
      test(c.name, () {
        final id = DebridFilePicker.pick(
          c.files,
          fileId: c.fileId,
          hintFileName: c.hintFileName,
          hintFileId: c.hintFileId,
          season: c.season,
          episode: c.episode,
        );

        expect(id, c.expectedId);
      });
    }

    test('no files: nothing to pick', () {
      expect(DebridFilePicker.pick(const []), isNull);
    });
  });
}
