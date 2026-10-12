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

  group('LiveTvPlaylist.displaySource (REV-137)', () {
    LiveTvPlaylist playlist(String urlOrPath, {required bool isLocal}) =>
        LiveTvPlaylist(
          name: 'TV',
          urlOrPath: urlOrPath,
          isLocal: isLocal,
          type: PlaylistType.m3u,
        );

    test('a URL shows only its site, never the login', () {
      final remote = playlist(
        'http://iptv.example.com:8080/get.php?username=me&password=secret',
        isLocal: false,
      );

      expect(remote.displaySource, 'iptv.example.com');
    });

    test('a local playlist shows its file name', () {
      expect(
        playlist('channels.m3u', isLocal: true).displaySource,
        'channels.m3u',
      );
    });
  });
}
