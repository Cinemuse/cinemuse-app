enum VideoResolution {
  r2160p('4K'),
  r1440p('1440p'),
  r1080p('1080p'),
  r720p('720p'),
  r480p('480p'),
  unknown('Unknown');

  final String label;
  const VideoResolution(this.label);
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
  ddPlus('Dolby Digital Plus'),
  dd('Dolby Digital'),
  aac('AAC'),
  unknown('Unknown');

  final String label;
  const AudioFormat(this.label);
}

enum ReleaseQuality {
  cam('CAM'),
  telesync('TS'),
  dvdrip('DVDRip'),
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
  none('None');

  final String label;
  const ReleaseFlag(this.label);
}

class StreamMetadata {
  final VideoMetadata video;
  final AudioMetadata audio;
  final List<String> languages;
  final ReleaseQuality quality;
  final List<ReleaseFlag> flags;
  final String? size; // Human readable size (e.g. "1.5 GB")
  final Map<String, dynamic>? custom; // For provider-specific flags like YouTube's needsAudio

  const StreamMetadata({
    required this.video,
    required this.audio,
    this.languages = const [],
    this.quality = ReleaseQuality.unknown,
    this.flags = const [],
    this.size,
    this.custom,
  });

  factory StreamMetadata.empty() => const StreamMetadata(
    video: VideoMetadata(),
    audio: AudioMetadata(),
  );

  StreamMetadata copyWith({
    VideoMetadata? video,
    AudioMetadata? audio,
    List<String>? languages,
    ReleaseQuality? quality,
    List<ReleaseFlag>? flags,
    String? size,
    Map<String, dynamic>? custom,
  }) {
    return StreamMetadata(
      video: video ?? this.video,
      audio: audio ?? this.audio,
      languages: languages ?? this.languages,
      quality: quality ?? this.quality,
      flags: flags ?? this.flags,
      size: size ?? this.size,
      custom: custom ?? this.custom,
    );
  }

  StreamMetadata copyWithCustom(Map<String, dynamic> customData) {
    return copyWith(custom: {...?custom, ...customData});
  }

  bool get isItalian => languages.contains('ITA');
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

  const AudioMetadata({
    this.formats = const [],
    this.channels,
  });

  bool get isAtmos => formats.contains(AudioFormat.atmos);
}
