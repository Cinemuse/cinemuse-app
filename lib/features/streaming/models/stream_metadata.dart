enum VideoResolution {
  r2160p('4K', '4K'),
  r1440p('1440p', '2K'),
  r1080p('1080p', 'FHD'),
  r720p('720p', 'HD'),
  r480p('480p', 'SD'),
  unknown('Unknown', 'Unknown');

  final String label;

  /// The name shown on a stream's row in the player.
  final String friendlyLabel;
  const VideoResolution(this.label, this.friendlyLabel);
}

enum VideoCodec {
  hevc('HEVC/x265'),
  h264('AVC/x264'),
  av1('AV1'),
  unknown('Unknown');

  final String label;
  const VideoCodec(this.label);
}

enum AudioFormat {
  atmos('Dolby Atmos'),
  dts('DTS'),
  trueHd('Dolby TrueHD'),
  ddPlus('Dolby Digital Plus'),
  dd('Dolby Digital'),
  flac('FLAC'),
  opus('Opus'),
  aac('AAC'),
  unknown('Unknown');

  final String label;
  const AudioFormat(this.label);
}

enum ReleaseQuality {
  cam('CAM'),
  telesync('TS'),
  dvdrip('DVDRip'),
  hdrip('HDRip'),
  hdtv('HDTV'),
  webdl('WEB-DL'),
  bluray('BluRay'),
  unknown('Unknown');

  final String label;
  const ReleaseQuality(this.label);
}

enum ReleaseFlag {
  proper('PROPER'),
  repack('REPACK'),
  extended('EXTENDED'),
  multi('MULTI'),
  dual('DUAL'),

  /// A screener or a telecine.
  screener('SCREENER'),
  threeD('3D'),
  none('None');

  final String label;
  const ReleaseFlag(this.label);
}

/// Languages that push a stream down the list. Kept with the stream's details
/// and never shown on its row.
enum ForeignLanguage {
  russian,
  ukrainian,
  french,
  german,
  spanish,

  /// A team known for Russian dubs, named in the release.
  russianDubTeam,
}

class StreamMetadata {
  final VideoMetadata video;
  final AudioMetadata audio;
  final List<String> languages;
  final List<ForeignLanguage> foreignLanguages;
  final ReleaseQuality quality;
  final List<ReleaseFlag> flags;
  final String? size; // Human readable size (e.g. "1.5 GB")
  final Map<String, dynamic>?
  custom; // For provider-specific flags like YouTube's needsAudio

  const StreamMetadata({
    required this.video,
    required this.audio,
    this.languages = const [],
    this.foreignLanguages = const [],
    this.quality = ReleaseQuality.unknown,
    this.flags = const [],
    this.size,
    this.custom,
  });

  factory StreamMetadata.empty() =>
      const StreamMetadata(video: VideoMetadata(), audio: AudioMetadata());

  StreamMetadata copyWith({
    VideoMetadata? video,
    AudioMetadata? audio,
    List<String>? languages,
    List<ForeignLanguage>? foreignLanguages,
    ReleaseQuality? quality,
    List<ReleaseFlag>? flags,
    String? size,
    Map<String, dynamic>? custom,
  }) {
    return StreamMetadata(
      video: video ?? this.video,
      audio: audio ?? this.audio,
      languages: languages ?? this.languages,
      foreignLanguages: foreignLanguages ?? this.foreignLanguages,
      quality: quality ?? this.quality,
      flags: flags ?? this.flags,
      size: size ?? this.size,
      custom: custom ?? this.custom,
    );
  }
}

class VideoMetadata {
  final VideoResolution resolution;
  final VideoCodec codec;
  final bool isHDR;
  final bool isDV;
  final bool is10Bit;

  const VideoMetadata({
    this.resolution = VideoResolution.unknown,
    this.codec = VideoCodec.unknown,
    this.isHDR = false,
    this.isDV = false,
    this.is10Bit = false,
  });
}

class AudioMetadata {
  final List<AudioFormat> formats;
  final int? channels; // e.g. 6 for 5.1

  const AudioMetadata({this.formats = const [], this.channels});

  bool get isAtmos => formats.contains(AudioFormat.atmos);
}
