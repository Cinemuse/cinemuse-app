import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cinemuse_app/core/services/youtube_service.dart';

class YoutubeHandler {
  final YoutubeService _ytService;
  String? _localAudioPath;

  YoutubeHandler(this._ytService);

  void cleanup() {
    if (_localAudioPath != null) {
      final file = File(_localAudioPath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _localAudioPath = null;
    }
  }

  Future<String?> downloadAudioToTempFile() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/yt_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Ensure any previous temp file is cleaned up before starting a new download
      cleanup();
      
      final resultPath = await _ytService.downloadAudioToFile(path);
      _localAudioPath = resultPath;
      return resultPath;
    } catch (e) {
      print('YoutubeHandler: Error downloading audio: $e');
      return null;
    }
  }

  Map<String, String> get youtubeHeaders => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Referer': 'https://www.youtube.com/',
  };

  void dispose() {
    cleanup();
  }
}
