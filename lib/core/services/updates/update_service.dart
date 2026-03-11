import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

enum UpdateStatus {
  initial,
  checking,
  available,
  downloading,
  readyToInstall,
  upToDate,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final String? latestVersion;
  final String? currentVersion;
  final double progress;
  final String? error;
  final String? downloadUrl;

  UpdateState({
    required this.status,
    this.latestVersion,
    this.currentVersion,
    this.progress = 0,
    this.error,
    this.downloadUrl,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? latestVersion,
    String? currentVersion,
    double? progress,
    String? error,
    String? downloadUrl,
  }) {
    return UpdateState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(UpdateState(status: UpdateStatus.initial));

  final Dio _dio = Dio();

  String get _owner => dotenv.env['GITHUB_OWNER'] ?? '';
  String get _repo => dotenv.env['GITHUB_REPO'] ?? '';

  Future<void> checkForUpdates() async {
    if (_owner.isEmpty || _repo.isEmpty) return;

    state = state.copyWith(status: UpdateStatus.checking);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );

      final latestTag = response.data['tag_name'] as String;
      final downloadUrl = _getDownloadUrl(response.data);

      if (_isNewer(latestTag, currentVersion, packageInfo.buildNumber)) {
        state = state.copyWith(
          status: UpdateStatus.available,
          latestVersion: latestTag,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
        );
      } else {
        state = state.copyWith(status: UpdateStatus.upToDate, currentVersion: currentVersion);
      }
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, error: e.toString());
    }
  }

  String? _getDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List;
    if (Platform.isAndroid) {
      final apk = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.apk'),
        orElse: () => null,
      );
      return apk?['browser_download_url'];
    } else if (Platform.isWindows) {
      // Look for the ZIP bundle first
      final zip = assets.firstWhere(
        (a) => (a['name'] as String).endsWith('.zip'),
        orElse: () => null,
      );
      return zip?['browser_download_url'];
    }
    return null;
  }

  bool _isNewer(String latestTag, String currentName, String currentBuild) {
    // Parse latest: v1.0.1+15 -> name: 1.0.1, build: 15
    final tagMatch = RegExp(r'v?(\d+\.\d+\.\d+)(?:\+(\d+))?').firstMatch(latestTag);
    if (tagMatch == null) return false;

    final latestName = tagMatch.group(1)!;
    final latestBuild = int.tryParse(tagMatch.group(2) ?? '0') ?? 0;

    final curBuild = int.tryParse(currentBuild) ?? 0;

    // First compare semantic version names
    List<int> latestParts = latestName.split('.').map(int.parse).toList();
    List<int> currentParts = currentName.split('.').map(int.parse).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    // If semantic names are equal, compare build numbers
    return latestBuild > curBuild;
  }

  Future<void> startUpdate() async {
    if (state.downloadUrl == null) return;

    if (Platform.isAndroid) {
      _startAndroidUpdate();
    } else if (Platform.isWindows) {
      _startWindowsUpdate();
    } else {
      // Fallback: open browser
      final url = Uri.parse(state.downloadUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  void _startAndroidUpdate() {
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);
    
    try {
      OtaUpdate().execute(state.downloadUrl!).listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              state = state.copyWith(progress: double.tryParse(event.value ?? '0') ?? 0);
              break;
            case OtaStatus.INSTALLING:
              state = state.copyWith(status: UpdateStatus.readyToInstall);
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              state = state.copyWith(status: UpdateStatus.error, error: event.status.toString());
              break;
            default:
              // Handle other statuses if necessary
              break;
          }
        },
      );
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, error: e.toString());
    }
  }

  Future<void> _startWindowsUpdate() async {
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = state.downloadUrl!.split('/').last;
      final zipFile = File(p.join(tempDir.path, fileName));

      await _dio.download(
        state.downloadUrl!,
        zipFile.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = state.copyWith(progress: (received / total) * 100);
          }
        },
      );

      state = state.copyWith(status: UpdateStatus.readyToInstall);

      // 1. Extract the ZIP to a temporary "update" folder
      final extractPath = p.join(tempDir.path, 'cinemuse_update');
      final bytes = zipFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File(p.join(extractPath, filename))
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory(p.join(extractPath, filename)).createSync(recursive: true);
        }
      }

      // 2. Create the .bat script to handle the file swap
      final currentAppDir = p.dirname(Platform.resolvedExecutable);
      final exeName = p.basename(Platform.resolvedExecutable);
      final scriptFile = File(p.join(tempDir.path, 'updater.bat'));

      final scriptContent = '''
@echo off
timeout /t 3 /nobreak > nul
xcopy /s /e /y /i "$extractPath\\*" "$currentAppDir"
start "" "$currentAppDir\\$exeName"
cd /d %temp%
rd /s /q "$extractPath"
del "%~f0"
''';

      scriptFile.writeAsStringSync(scriptContent);

      // 3. Launch the script and exit
      await Process.start(scriptFile.path, [], mode: ProcessStartMode.detached);
      exit(0);
      
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, error: e.toString());
    }
  }
}
