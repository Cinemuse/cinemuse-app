import 'dart:convert';
import 'package:uuid/uuid.dart';

enum PlaylistType { m3u, json }

class LiveTvPlaylist {
  final String id;
  final String name;
  final String urlOrPath;
  final bool isLocal;
  final PlaylistType type;
  final bool isEnabled;

  LiveTvPlaylist({
    String? id,
    required this.name,
    required this.urlOrPath,
    required this.isLocal,
    required this.type,
    this.isEnabled = true,
  }) : id = id ?? const Uuid().v4();

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
      isEnabled: json['isEnabled'] as bool? ?? true, // default true for legacy entries
    );
  }

  String encode() => json.encode(toJson());

  factory LiveTvPlaylist.decode(String str) =>
      LiveTvPlaylist.fromJson(json.decode(str) as Map<String, dynamic>);
}
