import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:cinemuse_app/features/live_tv/domain/live_tv_source.dart';

/// A TV guide (XMLTV or JSON). The format is read from the content, so the
/// user never picks it.
class LiveTvGuide implements LiveTvSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String urlOrPath;
  @override
  final bool isLocal;
  @override
  final bool isEnabled;
  @override
  final bool isBuiltIn;

  LiveTvGuide({
    String? id,
    required this.name,
    required this.urlOrPath,
    required this.isLocal,
    this.isEnabled = true,
    this.isBuiltIn = false,
  }) : id = id ?? const Uuid().v4();

  static const cinemuseId = 'cinemuse-epg';

  /// The guide of the Cinemuse playlist's channels, at [url].
  factory LiveTvGuide.cinemuse(String url, {bool isEnabled = true}) =>
      LiveTvGuide(
        id: cinemuseId,
        name: 'Cinemuse IPTV',
        urlOrPath: url,
        isLocal: false,
        isEnabled: isEnabled,
        isBuiltIn: true,
      );

  /// A guess from the file name, for the badge only: the content decides.
  bool get looksLikeJson {
    final path = isLocal ? urlOrPath : Uri.tryParse(urlOrPath)?.path ?? '';
    return p.extension(path).toLowerCase() == '.json';
  }

  LiveTvGuide copyWith({bool? isEnabled}) => LiveTvGuide(
    id: id,
    name: name,
    urlOrPath: urlOrPath,
    isLocal: isLocal,
    isEnabled: isEnabled ?? this.isEnabled,
    isBuiltIn: isBuiltIn,
  );

  @override
  String encode() => json.encode({
    'id': id,
    'name': name,
    'urlOrPath': urlOrPath,
    'isLocal': isLocal,
    'isEnabled': isEnabled,
  });

  factory LiveTvGuide.decode(String str) {
    final map = json.decode(str) as Map<String, dynamic>;
    return LiveTvGuide(
      id: map['id'] as String,
      name: map['name'] as String,
      urlOrPath: map['urlOrPath'] as String,
      isLocal: map['isLocal'] as bool,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}
