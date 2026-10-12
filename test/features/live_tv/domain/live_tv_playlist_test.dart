import 'package:cinemuse_app/features/live_tv/domain/live_tv_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaylistType.fromPath (REV-136)', () {
    test('reads the extension, not the folder names', () {
      expect(
        PlaylistType.fromPath(r'C:\Users\me\json\channels.m3u'),
        PlaylistType.m3u,
      );
      expect(
        PlaylistType.fromPath('/home/me/json/list.m3u8'),
        PlaylistType.m3u,
      );
    });

    test('a .json file is JSON, in any case', () {
      expect(PlaylistType.fromPath('/home/me/list.json'), PlaylistType.json);
      expect(PlaylistType.fromPath(r'C:\tv\LIST.JSON'), PlaylistType.json);
    });
  });
}
