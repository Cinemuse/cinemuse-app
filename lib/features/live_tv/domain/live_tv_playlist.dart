import 'dart:convert';
import 'package:uuid/uuid.dart';

enum PlaylistType { m3u, json }

class LiveTvPlaylist {
  final String id;
  final String name;
  final String urlOrPath;
  final bool isLocal;
  final PlaylistType type;

  LiveTvPlaylist({
    String? id,
    required this.name,
    required this.urlOrPath,
    required this.isLocal,
    required this.type,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'urlOrPath': urlOrPath,
      'isLocal': isLocal,
      'type': type.name,
    };
  }

  factory LiveTvPlaylist.fromJson(Map<String, dynamic> json) {
    return LiveTvPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      urlOrPath: json['urlOrPath'] as String,
      isLocal: json['isLocal'] as bool,
      type: PlaylistType.values.firstWhere((e) => e.name == json['type']),
    );
  }

  String encode() => json.encode(toJson());

  factory LiveTvPlaylist.decode(String str) =>
      LiveTvPlaylist.fromJson(json.decode(str) as Map<String, dynamic>);
}
