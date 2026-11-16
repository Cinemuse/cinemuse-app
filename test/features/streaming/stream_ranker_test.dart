import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_ranker.dart';
import 'package:cinemuse_app/features/streaming/ranking/stream_parser.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

void main() {
  group('StreamRanker scoring', () {
    test('Should prioritize Italian streams', () {
      final itaStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie Title ITA ENG 1080p',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final engStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie Title ENG 1080p',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      final itaScore = StreamRanker.score(itaStream);
      final engScore = StreamRanker.score(engStream);

      expect(
        itaScore > engScore,
        isTrue,
        reason: 'Italian should have higher score than English',
      );
    });

    test('Should massively boost Multi (ITA+ENG)', () {
      final multiStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie.Title.MULTI.ITA.ENG.1080p',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final itaOnlyStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie.Title.ITA.1080p',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      final multiScore = StreamRanker.score(multiStream);
      final itaScore = StreamRanker.score(itaOnlyStream);

      expect(
        multiScore > itaScore,
        isTrue,
        reason: 'Multi should have higher score than single language',
      );
    });

    test('Should prioritize 4K/2160p over 1080p', () {
      final k4Stream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie 4K HEVC',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );
      final hdStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie 1080p HEVC',
        infoHash: 'hash2',
        magnet: 'mag2',
        seeds: 10,
        provider: 'P1',
      );

      expect(
        StreamRanker.score(k4Stream) > StreamRanker.score(hdStream),
        isTrue,
      );
    });

    test('Should penalize Russian releases without Italian', () {
      final rusStream = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie.RUSSIAN.lostfilm',
        infoHash: 'hash1',
        magnet: 'mag1',
        seeds: 10,
        provider: 'P1',
      );

      expect(StreamRanker.score(rusStream) < 0, isTrue);
    });
  });

  group('StreamRanker parsing', () {
    test('Should parse resolution correctly', () {
      final meta = StreamParser.parse('Movie 2160p HDR');
      expect(meta.video.resolution, equals(VideoResolution.r2160p));
    });

    test('Should parse 10bit and HDR', () {
      final meta = StreamParser.parse('Movie.1080p.10bit.HDR.HEVC');
      expect(meta.video.is10Bit, isTrue);
      expect(meta.video.isHDR, isTrue);
    });

    test('Should detect languages', () {
      final meta = StreamParser.parse('Movie ITA ENG');
      expect(meta.languages, contains('ITA'));
      expect(meta.languages, contains('ENG'));
    });

    test('Should parse file size', () {
      final meta = StreamParser.parse('Movie [12.5 GB]');
      expect(meta.size, equals('12.5 GB'));
    });

    test('matches short tags only as whole words (STR-02)', () {
      final meta = StreamParser.parse(
        'Spider-Man.Across.the.Multiverse.Individual.2k23.HDRezka',
      );
      expect(meta.video.resolution, VideoResolution.unknown);
      expect(meta.video.isHDR, isFalse);
      expect(meta.flags, isEmpty);
      expect(meta.languages, isEmpty);
    });

    test('detects Japanese and MULTI audio (REV-25)', () {
      expect(StreamParser.parse('Anime.S01E01.JPN.1080p').languages, ['JPN']);
      expect(StreamParser.parse('Anime.S01E01.Japanese.1080p').languages, [
        'JPN',
      ]);
      expect(StreamParser.parse('Movie.MULTI.1080p').languages, ['MULTI']);
    });

    test('only a real unit counts as a file size', () {
      String? size(String title) => StreamParser.parse(title).size;

      expect(size('Movie 2024 BluRay 1080p 14.2 GB'), '14.2 GB');
      expect(size('Movie 1080p 10bit x265 8.4 GB'), '8.4 GB');
      expect(size('Movie 1080p 10 Bit x265'), isNull);
      expect(size('Movie 1080p DDP5.1 BluRay'), isNull);
      expect(size('Movie 700MB'), '700 MB');
    });

    test('E-AC3 is Dolby Digital Plus only', () {
      for (final title in ['Movie E-AC3', 'Movie EAC3']) {
        expect(StreamParser.parse(title).audio.formats, [AudioFormat.ddPlus]);
      }
      expect(StreamParser.parse('Movie AC3').audio.formats, [AudioFormat.dd]);
    });

    test('sound formats are not read from inside other words', () {
      List<AudioFormat> formats(String title) =>
          StreamParser.parse(title).audio.formats;

      expect(formats('La Atmosfera Perfetta 2021 1080p'), isEmpty);
      expect(formats('Isaac 2020 1080p'), isEmpty);
      expect(formats('Movie 1080p Atmos AAC2.0'), [
        AudioFormat.atmos,
        AudioFormat.aac,
      ]);
    });

    test('reads a name written with underscores', () {
      final meta = StreamParser.parse(
        'Movie_2023_1080p_HDR_MULTI_ITA_ENG_WEB-DL.mkv',
      );

      expect(meta.video.resolution, VideoResolution.r1080p);
      expect(meta.video.isHDR, isTrue);
      expect(meta.flags, [ReleaseFlag.multi]);
      expect(meta.languages, ['ITA', 'ENG', 'MULTI']);
    });
  });

  group('StreamParser reads labels after the film title', () {
    List<String> languages(String title) => StreamParser.parse(title).languages;

    test('a title word is not a label', () {
      expect(languages('The Italian Job 2003 1080p ENG'), ['ENG']);
      expect(languages('The.Italian.Job.1969.1080p'), isEmpty);
      expect(languages('Italian.S01E01.ENG'), ['ENG']);
      expect(StreamParser.parse('Extended Family 2021 1080p').flags, isEmpty);
      expect(
        StreamParser.parse('Web 2020 720p').quality,
        isNot(ReleaseQuality.webdl),
      );
    });

    test('Torrentio: the first line is the source, not where labels start', () {
      final meta = StreamParser.parse(
        '[Torrentio\n4k DV | HDR10+] The Italian Job (2003) 2160p H265 ita eng '
        '👤 4 💾 3.4 GB ⚙️ TorrentGalaxy 🇬🇧 / 🇮🇹',
      );

      expect(meta.video.resolution, VideoResolution.r2160p);
      expect(meta.video.isDV, isTrue);
      expect(meta.video.isHDR, isTrue);
      expect(meta.languages, ['ITA', 'ENG']);
      expect(meta.size, '3.4 GB');
    });

    test('the source line and the flags still count', () {
      final meta = StreamParser.parse(
        '[Torrentio\n1080p] The Italian Job 1969 BluRay 👤 5 💾 1.6 GB ⚙️ YTS 🇮🇹',
      );

      expect(meta.video.resolution, VideoResolution.r1080p);
      expect(meta.languages, ['ITA']);
    });

    test('a label in brackets before the year counts', () {
      expect(languages('[ITA] Movie 2020 1080p'), ['ITA']);
      expect(languages('Movie [ITA] 2020 1080p'), ['ITA']);
    });

    test('without a year, episode or size the whole name is read', () {
      expect(languages('Movie ITA ENG'), ['ITA', 'ENG']);
      expect(languages('ITA Movie BluRay'), ['ITA']);
    });
  });

  group('StreamParser subtitles are not sound', () {
    List<String> languages(String title) => StreamParser.parse(title).languages;

    test('languages named as subtitles do not count', () {
      expect(languages('Movie 2020 1080p ENG Sub ITA'), ['ENG']);
      expect(languages('Show - 05 JAP SUB ITA'), ['JPN']);
      expect(languages('Movie 2020 ita eng AC3 sub ita eng'), ['ITA', 'ENG']);
      expect(languages('Movie 2020 ENG SUB-ITA'), ['ENG']);
      expect(languages('Movie 2020 ENG Sub ITA+ENG ~ 1080p'), ['ENG']);
      expect(languages('Movie 2020 ENG [Sub ITA]'), ['ENG']);
    });

    test('a language before the word sub stays sound', () {
      expect(languages('Show [TV] [1998] [JAP+Sub]'), ['JPN']);
      expect(languages('Show.S02.1080p.AC3.ITA.ENG.SUBS.HEVC'), ['ITA', 'ENG']);
      expect(languages('Movie 2010 Eng Ita Multi-Subs 4K 1080p'), [
        'ITA',
        'ENG',
      ]);
    });

    test('labels right before the size count, though a year comes later', () {
      final meta = StreamParser.parse(
        'La Vita AC3 5.1 ITA.ENG 1080p H265 sub eng.rus (1997) Sp33dy94 MIRCrew',
      );

      expect(meta.languages, ['ITA', 'ENG']);
    });

    test('with Italian sound, foreign subtitles cost nothing', () {
      List<ForeignLanguage> foreign(String title) =>
          StreamParser.parse(title).foreignLanguages;

      expect(foreign('Movie 2020 1080p ITA ENG sub eng.rus'), isEmpty);
      expect(foreign('Movie 2020 1080p ITA-ENG-RUS'), [
        ForeignLanguage.russian,
      ]);
      expect(foreign('Movie 2020 1080p MVO + Sub rus eng'), [
        ForeignLanguage.russian,
      ]);
    });

    test('a flag does not bring a subtitle back', () {
      expect(
        languages('Movie 2020 1080p ENG Sub ITA 👤 3 💾 1 GB ⚙️ x 🇬🇧 / 🇮🇹'),
        ['ENG'],
      );
    });

    test('subtitles for many languages are not MULTI', () {
      for (final title in [
        'Show - 05 [1080p][Multi-Subs]',
        'Show - 05 [1080p] Multi Subs',
        'Show - 05 [1080p] MultiSub',
        'Show 2020 1080p Sub Multi',
      ]) {
        final meta = StreamParser.parse(title);
        expect(meta.languages, isNot(contains('MULTI')), reason: title);
        expect(meta.flags, isNot(contains(ReleaseFlag.multi)), reason: title);
      }
      expect(languages('Movie 2020 1080p Multi Audio'), ['MULTI']);
    });
  });

  group('StreamParser picture size', () {
    VideoResolution size(String title) =>
        StreamParser.parse(title).video.resolution;

    test('a real size beats the word', () {
      expect(size('Movie 4K Remaster 1080p'), VideoResolution.r1080p);
      expect(size('Movie 2008 UHD BDRip 1080p HDR10'), VideoResolution.r1080p);
    });

    test('every way a name writes it', () {
      expect(size('Movie 1080i BluRay'), VideoResolution.r1080p);
      expect(size('Movie 1920x1080 BluRay'), VideoResolution.r1080p);
      expect(size('Movie 1920x800 BluRay'), VideoResolution.r1080p);
      expect(size('Movie 1448x1080 BluRay'), VideoResolution.r1080p);
      expect(size('Movie 1280x720'), VideoResolution.r720p);
      expect(size('Movie 2160 HDR'), VideoResolution.r2160p);
      expect(size('Movie 1080p48 x264'), VideoResolution.r1080p);
      expect(size('Movie FHD WEB'), VideoResolution.r1080p);
      expect(size('Movie 4K HEVC'), VideoResolution.r2160p);
    });

    test('576p and 360p show SD', () {
      for (final title in ['Movie 576p', 'Movie 360p', 'Movie 480p']) {
        expect(size(title).friendlyLabel, 'SD', reason: title);
      }
    });

    test('seeders are not a picture size', () {
      expect(size('Movie 👤 2160 💾 1 GB'), VideoResolution.unknown);
    });
  });

  group('StreamParser labels', () {
    test('Dolby Vision and HDR10+', () {
      for (final title in [
        'Movie 2020 Dolby Vision',
        'Movie 2020 DolbyVision',
        'Movie 2020 HDRDV',
      ]) {
        expect(StreamParser.parse(title).video.isDV, isTrue, reason: title);
      }
      for (final title in [
        'Movie 2020 HDR10Plus',
        'Movie 2020 HDR10+ x265',
        'Movie 2020 HDRDV',
      ]) {
        expect(StreamParser.parse(title).video.isHDR, isTrue, reason: title);
      }
      expect(StreamParser.parse('Movie 2020 HDRip').video.isHDR, isFalse);
    });

    test('10-bit', () {
      for (final title in [
        'Movie 2020 10-bit',
        'Movie 2020 10 bit',
        'Movie 2020 10bit',
        'Movie 2020 Hi10P',
      ]) {
        expect(StreamParser.parse(title).video.is10Bit, isTrue, reason: title);
      }
    });

    test("Director's Cut shows EXTENDED", () {
      for (final title in [
        "Movie 2020 Director's Cut",
        'Movie.2020.Directors.Cut',
        'Movie 2020 Extended',
      ]) {
        expect(
          StreamParser.parse(title).flags,
          contains(ReleaseFlag.extended),
          reason: title,
        );
      }
    });

    test('Italiano counts', () {
      expect(StreamParser.parse('Movie 2020 Italiano').languages, ['ITA']);
    });

    test('Dual Audio shows DUAL, and MULTI wins when both are there', () {
      for (final title in [
        'Movie 2020 Dual Audio',
        'Movie 2020 Dual-Audio',
        'Movie 2020 DualAudio',
        'Movie.2020.1080p-Dual-Lat',
      ]) {
        expect(StreamParser.parse(title).languages, ['DUAL'], reason: title);
      }
      expect(StreamParser.parse('Movie 2020 ENG Dual Audio').languages, [
        'ENG',
        'DUAL',
      ]);
      expect(StreamParser.parse('Movie 2020 MULTI Dual Audio').languages, [
        'MULTI',
      ]);
    });
  });

  group('StreamParser size', () {
    String? size(String title) => StreamParser.parse(title).size;

    test('a comma is a decimal point', () {
      expect(size('Movie 2020 1,4 GB'), '1.4 GB');
    });

    test('terabytes', () {
      expect(size('Movie 2020 1.2 TB'), '1.2 TB');
    });

    test("Torrentio's size is the file's, not the season's", () {
      expect(
        size('Show S01 [17.5GB] Show.S01E03.mkv 👤 10 💾 1.3 GB ⚙️ x'),
        '1.3 GB',
      );
    });
  });

  group('StreamParser what the ranking reads', () {
    test('codecs', () {
      VideoCodec codec(String title) => StreamParser.parse(title).video.codec;

      expect(codec('Movie 2020 H.265'), VideoCodec.hevc);
      expect(codec('Movie 2020 H 265-GROUP'), VideoCodec.hevc);
      expect(codec('Movie 2020 H.264'), VideoCodec.h264);
      expect(codec('Movie 2020 H 264-GROUP'), VideoCodec.h264);
      expect(codec('Movie 2020 BDRip-AVC'), VideoCodec.h264);
    });

    test('kinds of release', () {
      ReleaseQuality quality(String title) => StreamParser.parse(title).quality;

      for (final word in [
        'Blu-Ray',
        'BRRip',
        'REMUX',
        'BDRemux',
        'BDRip',
        'BluRay',
      ]) {
        expect(
          quality('Movie 2020 $word'),
          ReleaseQuality.bluray,
          reason: word,
        );
      }
      for (final word in ['WEB', 'WEB.DL', 'WEB DL', 'WEB-DL', 'WEBRip']) {
        expect(quality('Movie 2020 $word'), ReleaseQuality.webdl, reason: word);
      }
      expect(quality('Movie 2020 HDTV'), ReleaseQuality.hdtv);
      expect(quality('Movie 2020 HDRip'), ReleaseQuality.hdrip);
      expect(quality('Movie 2020 HD-Rip'), ReleaseQuality.hdrip);
      expect(quality('Movie 2020 DVD'), ReleaseQuality.dvdrip);
      expect(quality('Movie 2020 DVDRip'), ReleaseQuality.dvdrip);
      expect(quality('Movie 2020 DVD5'), ReleaseQuality.dvdrip);
    });

    test('telesync: a file extension is not one', () {
      ReleaseQuality quality(String title) => StreamParser.parse(title).quality;

      expect(quality('Movie.2020.1080p.ts'), isNot(ReleaseQuality.telesync));
      expect(quality('Movie.2020.ts 👤 3'), isNot(ReleaseQuality.telesync));
      expect(quality('Movie.2020.TS.x264'), ReleaseQuality.telesync);
      expect(quality('Movie.2020.HDTS'), ReleaseQuality.telesync);
    });
  });

  group('StreamParser sound details', () {
    AudioMetadata audio(String title) => StreamParser.parse(title).audio;

    test('more sound formats', () {
      expect(audio('Movie 2020 DD 5.1').formats, [AudioFormat.dd]);
      expect(audio('Movie 2020 DD2.0').formats, [AudioFormat.dd]);
      expect(audio('Movie 2020 DD5 1').formats, [AudioFormat.dd]);
      expect(audio('Movie 2020 TrueHD 7.1').formats, [AudioFormat.trueHd]);
      expect(audio('Movie 2020 FLAC2.0').formats, [AudioFormat.flac]);
      expect(audio('Movie 2020 Opus 5.1').formats, [AudioFormat.opus]);
    });

    test('HDTS is not DTS', () {
      expect(audio('Movie 2020 HDTS').formats, isEmpty);
      expect(audio('Movie 2020 DTS-HD').formats, [AudioFormat.dts]);
      expect(audio('Movie 2020 x264.DTS5.1').formats, [AudioFormat.dts]);
    });

    test('channels are not a file size', () {
      expect(audio('Movie 2020 7.1 GB').channels, isNull);
      expect(audio('Movie 2020 5.1GB').channels, isNull);
      expect(audio('Movie 2020 12.0 GB').channels, isNull);
      expect(audio('Movie 2020 DDP7.1 8 GB').channels, 8);
      expect(audio('Movie 2020 AAC5.1').channels, 6);
      expect(audio('Movie 2020 AAC2.0').channels, 2);
    });
  });

  group('StreamParser foreign languages', () {
    List<ForeignLanguage> foreign(String title) =>
        StreamParser.parse(title).foreignLanguages;

    test('whole words, also in names with dots', () {
      expect(foreign('Movie.2020.RUS.1080p'), [ForeignLanguage.russian]);
      expect(foreign('Movie.2020.RUS'), [ForeignLanguage.russian]);
      expect(foreign('Movie 2020 Sub (Rus Eng)'), [ForeignLanguage.russian]);
      expect(foreign('Movie.2020.TRUEFRENCH'), [ForeignLanguage.french]);
      expect(foreign('Movie.2020.GER'), [ForeignLanguage.german]);
      expect(foreign('Movie.2020.Spanish'), [ForeignLanguage.spanish]);
      expect(foreign('Movie.2020.UKR'), [ForeignLanguage.ukrainian]);
    });

    test('words that only start the same are not languages', () {
      expect(foreign('Rush 2013 1080p Rush Space Gerald Fragile'), isEmpty);
    });

    test('words in the film title are not languages', () {
      expect(foreign('The French Dispatch 2021 1080p'), isEmpty);
      expect(foreign('The.Russian.2020.1080p'), isEmpty);
    });

    test('a dub team is told apart from the language', () {
      expect(foreign('Movie 2020 LostFilm'), [
        ForeignLanguage.russian,
        ForeignLanguage.russianDubTeam,
      ]);
      expect(foreign('Movie 2020 NewComers'), [ForeignLanguage.russianDubTeam]);
      expect(foreign('The Newcomers 2000 1080p'), isEmpty);
    });
  });

  group('StreamRanker uses the stored details', () {
    StreamCandidate stream(String title) => StreamCandidate(
      kind: StreamSourceKind.vod,
      title: title,
      infoHash: '',
      magnet: '',
      provider: 'P1',
    );

    int score(String title) =>
        StreamRanker.score(stream(title), preferredLanguage: 'it');

    test('a foreign name loses its points, a title like Rush does not', () {
      expect(score('Movie.2020.1080p') - score('Movie.2020.1080p.RUS'), 500);
      expect(score('Rush 2013 1080p'), score('Movie 2013 1080p'));
    });

    test('a dub team costs more unless the release is Italian', () {
      expect(
        score('Movie 2020 720p') - score('Movie 2020 720p LostFilm'),
        1300,
      );
      expect(
        score('Movie 2020 720p ITA') - score('Movie 2020 720p ITA LostFilm'),
        500,
      );
    });

    test('a stream with its own details ignores words in its title', () {
      final builtIn = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'The French Russian Ep.1 [Site]',
        infoHash: '',
        magnet: '',
        provider: 'Site',
        metadata: StreamMetadata.empty(),
      );

      expect(
        StreamRanker.score(builtIn),
        StreamRanker.score(
          stream('Plain').copyWith(metadata: StreamMetadata.empty()),
        ),
      );
    });

    test('HDTV and HDRip sit between DVD and WEB', () {
      final unknown = score('Movie 2020 1080p');

      expect(score('Movie 2020 1080p DVD') - unknown, 5);
      expect(score('Movie 2020 1080p HDTV') - unknown, 10);
      expect(score('Movie 2020 1080p HDRip') - unknown, 10);
      expect(score('Movie 2020 1080p WEB') - unknown, 20);
    });

    test('DUAL gives no language points', () {
      expect(score('Movie 2020 1080p Dual Audio'), score('Movie 2020 1080p'));
    });
  });

  group('StreamRanker preferred language (REV-25)', () {
    StreamCandidate stream(String title, List<String> languages) =>
        StreamCandidate(
          kind: StreamSourceKind.vod,
          title: title,
          infoHash: '',
          magnet: '',
          provider: 'P1',
          metadata: StreamMetadata(
            video: const VideoMetadata(resolution: VideoResolution.r1080p),
            audio: const AudioMetadata(),
            languages: languages,
          ),
        );

    test('with Japanese preferred, a JPN stream ranks first', () {
      final ita = stream('Anime Ep.1 ITA', ['ITA']);
      final jpn = stream('Anime Ep.1 SUB ITA', ['JPN']);

      final result = StreamRanker.rank([ita, jpn], preferredLanguage: 'ja');

      expect(result.first.title, jpn.title);
    });

    test('with Italian preferred, an ITA stream gets the full boost', () {
      final ita = stream('Movie ITA', ['ITA']);
      final eng = stream('Movie ENG', ['ENG']);

      expect(
        StreamRanker.score(ita, preferredLanguage: 'it') -
            StreamRanker.score(eng, preferredLanguage: 'it'),
        greaterThanOrEqualTo(1000),
      );
    });
  });

  group('StreamRanker ranking', () {
    test('Should sort by cache status first, then score', () {
      final uncachedHigh = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie ITA 4K Uncached',
        infoHash: 'h1',
        magnet: 'm1',
        seeds: 100,
        provider: 'P1',
        cachedOn: {}, // Not cached
      );
      final cachedLow = StreamCandidate(
        kind: StreamSourceKind.vod,
        title: 'Movie ENG 720p Cached',
        infoHash: 'h2',
        magnet: 'm2',
        seeds: 1,
        provider: 'P1',
        cachedOn: {'P1': true}, // Cached
      );

      final result = StreamRanker.rank([uncachedHigh, cachedLow]);

      expect(
        result.first.infoHash,
        equals('h2'),
        reason: 'Cached stream should be first',
      );
    });
  });
}
