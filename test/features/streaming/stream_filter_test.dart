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
