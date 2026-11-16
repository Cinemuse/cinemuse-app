import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';

enum PlaylistType {
  m3u,
  json;

  /// From the file's extension only: an `.m3u` inside a folder named
  /// "json" is still M3U (REV-136).
  static PlaylistType fromPath(String path) =>
      p.extension(path).toLowerCase() == '.json' ? json : m3u;
}

class LiveTvPlaylist implements LiveTvSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String urlOrPath;
  @override
  final bool isLocal;
  final PlaylistType type;
  @override
  final bool isEnabled;
  @override
  final bool isBuiltIn;

  LiveTvPlaylist({
    String? id,
    required this.name,
    required this.urlOrPath,
    required this.isLocal,
    required this.type,
    this.isEnabled = true,
    this.isBuiltIn = false,
  }) : id = id ?? const Uuid().v4();

  static const cinemuseId = 'cinemuse-iptv';

  /// The free-to-air channels served by the Cinemuse server at [url].
  factory LiveTvPlaylist.cinemuse(String url, {bool isEnabled = true}) =>
      LiveTvPlaylist(
        id: cinemuseId,
        name: 'Cinemuse IPTV',
        urlOrPath: url,
        isLocal: false,
        type: PlaylistType.m3u,
        isEnabled: isEnabled,
        isBuiltIn: true,
      );

  String get displaySource => LiveTvSource.displaySourceOf(this);

  LiveTvPlaylist copyWith({
    String? name,
    String? urlOrPath,
    bool? isLocal,
    PlaylistType? type,
    bool? isEnabled,
  }) {
    return LiveTvPlaylist(
      id: id,
      name: name ?? this.name,
      urlOrPath: urlOrPath ?? this.urlOrPath,
      isLocal: isLocal ?? this.isLocal,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'urlOrPath': urlOrPath,
      'isLocal': isLocal,
      'type': type.name,
      'isEnabled': isEnabled,
    };
  }

  factory LiveTvPlaylist.fromJson(Map<String, dynamic> json) {
    return LiveTvPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      urlOrPath: json['urlOrPath'] as String,
      isLocal: json['isLocal'] as bool,
      type: PlaylistType.values.firstWhere((e) => e.name == json['type']),
      isEnabled:
          json['isEnabled'] as bool? ?? true, // default true for legacy entries
    );
  }

  @override
  String encode() => json.encode(toJson());

  factory LiveTvPlaylist.decode(String str) =>
      LiveTvPlaylist.fromJson(json.decode(str) as Map<String, dynamic>);
}
