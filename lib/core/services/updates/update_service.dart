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
import 'dart:ffi';
import 'package:flutter/foundation.dart';

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
  final String? errorKey;
  final Map<String, String>? errorArgs;
  final String? downloadUrl;
  final String? releaseNotes;
  final CancelToken? cancelToken;

  UpdateState({
    required this.status,
    this.latestVersion,
    this.currentVersion,
    this.progress = 0,
    this.error,
    this.errorKey,
    this.errorArgs,
    this.downloadUrl,
    this.releaseNotes,
    this.cancelToken,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? latestVersion,
    String? currentVersion,
    double? progress,
    String? error,
    String? errorKey,
    Map<String, String>? errorArgs,
    String? downloadUrl,
    String? releaseNotes,
    CancelToken? cancelToken,
    bool clearCancelToken = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      errorKey: errorKey ?? this.errorKey,
      errorArgs: errorArgs ?? this.errorArgs,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      cancelToken: clearCancelToken ? null : (cancelToken ?? this.cancelToken),
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
    if (_owner.isEmpty || _repo.isEmpty) {
      debugPrint('UpdateService: GITHUB_OWNER or GITHUB_REPO is missing in .env');
      return;
    }

    state = state.copyWith(status: UpdateStatus.checking);
    debugPrint('UpdateService: Checking for updates for $_owner/$_repo...');

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );

      final latestTag = response.data['tag_name'] as String;
      final releaseNotes = response.data['body'] as String?;
      debugPrint('UpdateService: Current version: $currentVersion+${packageInfo.buildNumber}');
      debugPrint('UpdateService: Latest tag from GitHub: $latestTag');
      
      final downloadUrl = await _getDownloadUrl(response.data);
      debugPrint('UpdateService: Download URL: $downloadUrl');

      if (_isNewer(latestTag, currentVersion, packageInfo.buildNumber)) {
        debugPrint('UpdateService: New version available!');
        state = state.copyWith(
          status: UpdateStatus.available,
          latestVersion: latestTag,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      } else {
        debugPrint('UpdateService: App is up to date');
        state = state.copyWith(status: UpdateStatus.upToDate, currentVersion: currentVersion);
     }
    } catch (e) {
      debugPrint('UpdateService: Check for updates failed: $e');
      state = state.copyWith(status: UpdateStatus.error, errorKey: 'updateSourceError');
    }
  }

  void cancelUpdate() {
    state.cancelToken?.cancel('User cancelled');
    state = state.copyWith(status: UpdateStatus.available, progress: 0, clearCancelToken: true);
  }

  void dismissUpdate() {
    state = state.copyWith(status: UpdateStatus.upToDate);
  }

  Future<String?> _getDownloadUrl(Map<String, dynamic> releaseData) async {
    final assets = releaseData['assets'] as List;
    if (Platform.isAndroid) {
      // Use Abi.current() from dart:ffi to detect the architecture
      final currentAbi = Abi.current().toString();
      
      // Mapping of dart:ffi Abi to common GitHub asset naming patterns
      String? abiPattern;
      if (currentAbi.contains('arm64')) {
        abiPattern = 'arm64-v8a';
      } else if (currentAbi.contains('arm')) {
        abiPattern = 'armeabi-v7a';
      } else if (currentAbi.contains('x64')) {
        abiPattern = 'x86_64';
      }
      
      debugPrint('UpdateService: Detected ABI: $currentAbi -> Pattern: $abiPattern');

      // 1. Try to find an APK that matches the ABI pattern
      var apk = (abiPattern != null) ? assets.firstWhere(
        (a) {
          final name = (a['name'] as String).toLowerCase();
          return name.endsWith('.apk') && name.contains(abiPattern!);
        },
        orElse: () => null,
      ) : null;

      // 2. Fallback to generic release APK if no ABI match found
      apk ??= assets.firstWhere(
        (a) {
          final name = (a['name'] as String).toLowerCase();
          return name.endsWith('.apk') && (name.contains('release') || name.contains('universal') || !name.contains('-'));
        },
        orElse: () => null,
      );

      // 3. Last resort: first APK found
      apk ??= assets.firstWhere(
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
    } else if (Platform.isLinux) {
      // Look for AppImage, deb, or tar.gz
      final linuxAsset = assets.firstWhere(
        (a) => (a['name'] as String).toLowerCase().contains('linux') || 
               (a['name'] as String).endsWith('.appimage') ||
               (a['name'] as String).endsWith('.deb') ||
               (a['name'] as String).endsWith('.tar.gz'),
        orElse: () => null,
      );
      return linuxAsset?['browser_download_url'];
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
          debugPrint('UpdateService: OTA Event: ${event.status} - ${event.value}');
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              state = state.copyWith(progress: double.tryParse(event.value ?? '0') ?? 0);
              break;
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              debugPrint('UpdateService: OTA Installation starting...');
              state = state.copyWith(status: UpdateStatus.readyToInstall);
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              debugPrint('UpdateService: OTA Error: Already running');
              state = state.copyWith(status: UpdateStatus.error, error: 'An update is already in progress.');
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              debugPrint('UpdateService: OTA Error: Permission not granted');
              state = state.copyWith(status: UpdateStatus.error, error: 'Permission to install apps was denied.');
              break;
            case OtaStatus.INTERNAL_ERROR:
              debugPrint('UpdateService: OTA Error: Internal error');
              state = state.copyWith(status: UpdateStatus.error, error: 'Internal update error. Please try again.');
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              debugPrint('UpdateService: OTA Error: Download error');
              state = state.copyWith(status: UpdateStatus.error, error: 'Failed to download the update.');
              break;
            case OtaStatus.CHECKSUM_ERROR:
              debugPrint('UpdateService: OTA Error: Checksum error');
              state = state.copyWith(status: UpdateStatus.error, error: 'Update file is corrupted.');
              break;
            default:
              break;
          }
        },
        onError: (e) {
          debugPrint('UpdateService: OTA Stream Error: $e');
          state = state.copyWith(status: UpdateStatus.error, errorKey: 'updateFailed');
        },
      );
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, errorKey: 'updateFailed');
    }
  }

  Future<void> _startWindowsUpdate() async {
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);

    Directory? tempDir;
    File? zipFile;

    try {
      tempDir = await getTemporaryDirectory();
      final fileName = state.downloadUrl!.split('/').last;
      zipFile = File(p.join(tempDir.path, fileName));
      final cancelToken = CancelToken();
      
      state = state.copyWith(cancelToken: cancelToken);

      await _dio.download(
        state.downloadUrl!,
        zipFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = state.copyWith(progress: (received / total) * 100);
          }
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('UpdateService: Windows download cancelled');
        return;
      }
      debugPrint('UpdateService: Windows download failed: $e');
      String errorKey = 'updateNetworkError';
      if (e.type == DioExceptionType.badResponse && e.response?.statusCode == 404) {
        errorKey = 'updateSourceError';
      }
      state = state.copyWith(status: UpdateStatus.error, errorKey: errorKey);
      return;
    } catch (e) {
      debugPrint('UpdateService: Windows download unexpected error: $e');
      state = state.copyWith(status: UpdateStatus.error, errorKey: 'updateFailed');
      return;
    }

    try {
      state = state.copyWith(status: UpdateStatus.readyToInstall, clearCancelToken: true);

      // 1. Extract the ZIP to a temporary "update" folder
      final extractPath = p.join(tempDir.path, 'cinemuse_update');
      
      // Clean up any previous failed extraction
      final dir = Directory(extractPath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      
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
      
      // Ensure we use backslashes for Windows BAT script
      final winExtractPath = extractPath.replaceAll('/', '\\');
      final winAppDir = currentAppDir.replaceAll('/', '\\');
      final winExePath = p.join(winAppDir, exeName).replaceAll('/', '\\');

      final scriptContent = '''
@echo off
setlocal
:: 1. Self-Elevation Logic
>nul 2>&1 "%SYSTEMROOT%\\system32\\cacls.exe" "%SYSTEMROOT%\\system32\\config\\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrator privileges...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\\getadmin.vbs"
    "%temp%\\getadmin.vbs"
    exit /B
)
if exist "%temp%\\getadmin.vbs" ( del "%temp%\\getadmin.vbs" )

echo Waiting for app to close...
:wait_loop
tasklist /fi "ImageName eq $exeName" | find /i "$exeName" > nul
if %errorlevel% == 0 (
    timeout /t 1 /nobreak > nul
    goto wait_loop
)

echo Swapping files...
xcopy /s /e /y /i "$winExtractPath\\*" "$winAppDir" > "%temp%\\cinemuse_update_log.txt" 2>&1
if %errorlevel% neq 0 (
    echo Error during file swap. Check %temp%\\cinemuse_update_log.txt
    pause
    exit /B
)

echo Restarting app...
start "" "$winExePath"

echo Cleaning up...
rd /s /q "$winExtractPath"
del "%~f0"
''';

      scriptFile.writeAsStringSync(scriptContent);

      // 3. Launch the script and exit
      await Process.start(scriptFile.path, [], mode: ProcessStartMode.detached);
      exit(0);
      
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, errorKey: 'updateFailed');
    }
  }
}
