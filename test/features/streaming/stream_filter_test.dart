import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_filter.dart';
import 'package:flutter_test/flutter_test.dart';

StreamCandidate _stream(String title) => StreamCandidate(
  kind: StreamSourceKind.vod,
  title: title,
  infoHash: '',
  magnet: '',
  provider: 'P1',
);

List<String> _titles(List<StreamCandidate> streams) =>
    streams.map((s) => s.title).toList();

void main() {
  group('smart filter (STR-01)', () {
    List<String> smartFiltered(List<String> titles) => _titles(
      StreamFilter.apply(
        titles.map(_stream).toList(),
        smartFilter: true,
        maxResolution: VideoResolution.unknown,
      ),
    );

    test('keeps titles that only contain the letters of a tag', () {
      const titles = [
        'Camelot.1967.1080p.BluRay.x264',
        'El.Camino.2019.1080p.WEB-DL',
        'Scam.City.S01E01.720p.WEB-DL',
        'The.Scorpion.King.2002.1080p.BluRay',
        'Subsurface.2020.1080p.WEB-DL',
      ];

      expect(smartFiltered(titles), titles);
    });

    test('removes CAM, telesync, screener and 3D releases', () {
      expect(
        smartFiltered([
          'Movie.2024.CAM.x264',
          'Movie.2024.HDCAM.x264',
          'Movie.2024.TS.x264',
          'Movie.2024.TELESYNC.x264',
          'Movie.2024.DVDSCR.x264',
          'Movie.2024.SCREENER.x264',
          'Movie.2024.3D.HSBS.1080p.BluRay',
          'Movie.2024.1080p.BluRay.x264',
        ]),
        ['Movie.2024.1080p.BluRay.x264'],
      );
    });

    test('a film title is not a release tag', () {
      const titles = [
        'Cam 2018 1080p WEB-DL',
        'Step Up 3D (2010) 1080p H265 BluRay ita eng',
        '[Torrentio\n1080p] Step Up 3D (2010) 1080p 👤 13 💾 3.14 GB',
        'Movie.2024.1080p.WEB-DL.mp4.ts',
      ];

      expect(smartFiltered(titles), titles);
    });

    test('tags that underscores or short forms used to hide', () {
      expect(
        smartFiltered([
          'Film_SCR_1080p',
          'Movie.2024.TC.x264',
          'Movie.2024.HDTC.x264',
          'Movie.2024.TSSCREENER.x264',
          'Movie.2024.BD3D.1080p',
        ]),
        isEmpty,
      );
    });

    test('the tag in the source name counts', () {
      expect(
        smartFiltered([
          '[Torrentio\n1080p 3D] Up 3D BluRay 1080p48 x264',
          '[Torrentio\nTeleSync] Movie (2023) HDRip 👤 3',
          '[Torrentio\nCAM] Movie (2023) WEB 👤 3',
        ]),
        isEmpty,
      );
    });

    test('a telecine scan named in full is not hidden', () {
      const title = 'Movie [2008 35mm Film Scan Telecine 1080p]';

      expect(smartFiltered([title]), [title]);
    });

    test('a stream with its own details is judged by them, not its title', () {
      final stream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Cam 3D Ep.1 [Site]',
        infoHash: '',
        magnet: '',
        provider: 'Site',
        metadata: StreamMetadata.empty(),
      );

      expect(StreamFilter.isLowQuality(stream), isFalse);
    });

    test('keeps everything when the smart filter is off', () {
      final streams = [_stream('Movie.2024.CAM.x264')];

      expect(
        StreamFilter.apply(
          streams,
          smartFilter: false,
          maxResolution: VideoResolution.unknown,
        ),
        streams,
      );
    });
  });

  group('max resolution (STR-02)', () {
    List<String> limitedTo1080p(List<String> titles) => _titles(
      StreamFilter.apply(
        titles.map(_stream).toList(),
        smartFilter: false,
        maxResolution: VideoResolution.r1080p,
      ),
    );

    test('removes streams above the limit', () {
      expect(
        limitedTo1080p([
          'Movie.2160p.WEB-DL',
          'Movie.4K.HDR.WEB-DL',
          'Movie.1080p.WEB-DL',
        ]),
        ['Movie.1080p.WEB-DL'],
      );
    });

    test('a 480p limit does not read HDR or SDH as a resolution', () {
      const titles = ['Movie.HDR.WEB-DL', 'Movie.WEB-DL.SDH'];

      expect(
        _titles(
          StreamFilter.apply(
            titles.map(_stream).toList(),
            smartFilter: false,
            maxResolution: VideoResolution.r480p,
          ),
        ),
        titles,
      );
    });

    test('keeps streams whose resolution is unknown', () {
      expect(limitedTo1080p(['Movie.WEB-DL']), ['Movie.WEB-DL']);
    });
  });
}
