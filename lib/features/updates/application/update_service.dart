import 'dart:async';

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/update_archive_extractor.dart';
import 'package:cinemuse_app/features/updates/data/update_checksum.dart';
import 'package:cinemuse_app/features/updates/domain/release_version.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/data/windows_updater_script.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

// Not autoDispose: the update overlay shows this state for the whole session.
final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    ref.onDispose(() => _otaSubscription?.cancel());
    return UpdateState(status: UpdateStatus.initial);
  }

  static const _tag = 'UpdateService';
  final Dio _dio = Dio();

  /// The running Android download, so Cancel can stop it (REV-33).
  StreamSubscription<OtaEvent>? _otaSubscription;

  String get _owner => dotenv.env['GITHUB_OWNER'] ?? '';
  String get _repo => dotenv.env['GITHUB_REPO'] ?? '';

  Future<void> checkForUpdates() async {
    if (_owner.isEmpty || _repo.isEmpty) {
      AppLogger.warn(_tag, 'GITHUB_OWNER or GITHUB_REPO is missing in .env');
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isNotEmpty &&
          connectivity.first == ConnectivityResult.none) {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
        );
        return;
      }

      state = state.copyWith(status: UpdateStatus.checking);

      final response = await _dio.get(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );

      final latestTag = response.data['tag_name'] as String;
      final releaseNotes = response.data['body'] as String?;
      final downloadUrl = await _getDownloadUrl(response.data);
      AppLogger.debug(
        _tag,
        'Installed $currentVersion+${packageInfo.buildNumber}, '
        'latest $latestTag, download $downloadUrl',
      );

      if (isNewerRelease(latestTag, currentVersion, packageInfo.buildNumber)) {
        AppLogger.info(_tag, 'Update $latestTag available');
        state = state.copyWith(
          status: UpdateStatus.available,
          latestVersion: latestTag,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          checksumUrl: _checksumUrl(response.data),
          releaseNotes: releaseNotes,
        );
      } else {
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
        );
      }
    } catch (e) {
      AppLogger.warn(_tag, 'Update check failed', error: e);
      _fail('updateSourceError');
    }
  }

  void cancelUpdate() {
    state.cancelToken?.cancel('User cancelled');
    final otaSubscription = _otaSubscription;
    if (otaSubscription != null) {
      // Stops the Android download itself, not only the progress bar (REV-33).
      _otaSubscription = null;
      unawaited(otaSubscription.cancel());
      unawaited(
        OtaUpdate().cancel().catchError(
          (Object e) => AppLogger.warn(_tag, 'OTA cancel failed', error: e),
        ),
      );
    }
    state = state.copyWith(
      status: UpdateStatus.available,
      progress: 0,
      clearCancelToken: true,
    );
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

      AppLogger.debug(_tag, 'ABI $currentAbi -> APK pattern $abiPattern');

      // 1. Try to find an APK that matches the ABI pattern
      var apk = (abiPattern != null)
          ? assets.firstWhere((a) {
              final name = (a['name'] as String).toLowerCase();
              return name.endsWith('.apk') && name.contains(abiPattern!);
            }, orElse: () => null)
          : null;

      // 2. Fallback to generic release APK if no ABI match found
      apk ??= assets.firstWhere((a) {
        final name = (a['name'] as String).toLowerCase();
        return name.endsWith('.apk') &&
            (name.contains('release') ||
                name.contains('universal') ||
                !name.contains('-'));
      }, orElse: () => null);

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
        (a) =>
            (a['name'] as String).toLowerCase().contains('linux') ||
            (a['name'] as String).endsWith('.appimage') ||
            (a['name'] as String).endsWith('.deb') ||
            (a['name'] as String).endsWith('.tar.gz'),
        orElse: () => null,
      );
      return linuxAsset?['browser_download_url'];
    }
    return null;
  }

  String? _checksumUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List;
    final sums = assets.firstWhere(
      (a) => a['name'] == sha256SumsAssetName,
      orElse: () => null,
    );
    return sums?['browser_download_url'] as String?;
  }

  Future<void> startUpdate() async {
    if (state.downloadUrl == null) return;

    if (Platform.isAndroid) {
      _startAndroidUpdate();
    } else if (Platform.isWindows) {
      // Runs in the background and reports progress through `state`.
      unawaited(_startWindowsUpdate());
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
      _otaSubscription = OtaUpdate()
          .execute(state.downloadUrl!)
          .listen(
            _onOtaEvent,
            onError: (Object e, StackTrace st) {
              AppLogger.error(_tag, 'OTA failed', error: e, stackTrace: st);
              _fail('updateFailed');
            },
          );
    } catch (e, st) {
      AppLogger.error(_tag, 'OTA did not start', error: e, stackTrace: st);
      _fail('updateFailed');
    }
  }

  void _onOtaEvent(OtaEvent event) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        state = state.copyWith(
          progress: double.tryParse(event.value ?? '0') ?? 0,
        );
      case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
        AppLogger.info(_tag, 'OTA ${event.status.name}');
        state = state.copyWith(status: UpdateStatus.readyToInstall);
      case final status:
        final errorKey = otaErrorKey(status);
        if (errorKey == null) return;
        AppLogger.warn(_tag, 'OTA ${status.name}: ${event.value}');
        _fail(errorKey);
    }
  }

  Future<void> _startWindowsUpdate() async {
    final checksumUrl = state.checksumUrl;
    if (checksumUrl == null) {
      AppLogger.warn(_tag, 'Release has no $sha256SumsAssetName: not updating');
      _fail('updateIntegrityError');
      return;
    }
    final appDir = p.dirname(Platform.resolvedExecutable);
    if (!_canWriteTo(appDir)) {
      _fail('updateFolderNotWritable');
      return;
    }
    state = state.copyWith(status: UpdateStatus.downloading, progress: 0);

    try {
      final workDir = p.join(
        (await getTemporaryDirectory()).path,
        'cinemuse_update',
      );
      final zipFile = await _downloadVerifiedZip(workDir, checksumUrl);
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        clearCancelToken: true,
      );
      await _installAndRestart(zipFile, workDir, appDir);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger.info(_tag, 'Windows update cancelled');
        return;
      }
      AppLogger.warn(_tag, 'Windows update download failed', error: e);
      final isMissing = e.response?.statusCode == 404;
      _fail(isMissing ? 'updateSourceError' : 'updateNetworkError');
    } on ValidationFailure catch (e, st) {
      AppLogger.error(_tag, 'Windows update refused', error: e, stackTrace: st);
      _fail('updateIntegrityError');
    } catch (e, st) {
      AppLogger.error(_tag, 'Windows update failed', error: e, stackTrace: st);
      _fail('updateFailed');
    }
  }

  void _fail(String errorKey) {
    state = state.copyWith(
      status: UpdateStatus.error,
      errorKey: errorKey,
      clearCancelToken: true,
    );
  }

  /// The updater script runs without admin rights (SEC-03), so it can only
  /// replace an app in a folder the user can write to (not Program Files).
  bool _canWriteTo(String dir) {
    final probe = File(p.join(dir, '.cinemuse_update_check'));
    try {
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } on FileSystemException catch (e) {
      AppLogger.warn(
        _tag,
        'App folder is not writable: not updating',
        error: e,
      );
      return false;
    }
  }

  /// Downloads the ZIP into a fresh [workDir] and checks it against the
  /// release's `SHA256SUMS`. Throws a [ValidationFailure] if it doesn't match.
  Future<File> _downloadVerifiedZip(String workDir, String checksumUrl) async {
    final dir = Directory(workDir);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final url = state.downloadUrl!;
    final assetName = Uri.parse(url).pathSegments.last;
    final zipFile = File(p.join(workDir, assetName));
    final cancelToken = CancelToken();
    state = state.copyWith(cancelToken: cancelToken);

    await _dio.download(
      url,
      zipFile.path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          state = state.copyWith(progress: (received / total) * 100);
        }
      },
    );
    final sums = await _dio.get<String>(
      checksumUrl,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.plain),
    );
    await verifyUpdateChecksum(
      file: zipFile,
      assetName: assetName,
      sha256Sums: sums.data ?? '',
    );
    return zipFile;
  }

  /// Extracts the update, starts the script that swaps the files once the
  /// app has closed, and closes the app.
  Future<void> _installAndRestart(
    File zipFile,
    String workDir,
    String appDir,
  ) async {
    final filesDir = p.join(workDir, 'files');
    await extractUpdateArchive(zipFile.path, filesDir);

    final script = File(p.join(workDir, 'updater.bat'));
    await script.writeAsString(
      buildWindowsUpdaterScript(
        appPid: pid,
        sourceDir: filesDir,
        appDir: appDir,
        exePath: Platform.resolvedExecutable,
        workDir: workDir,
      ),
    );
    AppLogger.info(_tag, 'Update verified and extracted, restarting');
    await Process.start(script.path, [], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// The translation key for an Android update error, or `null` when [status]
/// is not an error (REV-29).
@visibleForTesting
String? otaErrorKey(OtaStatus status) => switch (status) {
  OtaStatus.ALREADY_RUNNING_ERROR => 'updateAlreadyRunning',
  OtaStatus.PERMISSION_NOT_GRANTED_ERROR => 'updatePermissionDenied',
  OtaStatus.DOWNLOAD_ERROR => 'updateNetworkError',
  OtaStatus.CHECKSUM_ERROR => 'updateIntegrityError',
  OtaStatus.INTERNAL_ERROR || OtaStatus.INSTALLATION_ERROR => 'updateFailed',
  OtaStatus.DOWNLOADING ||
  OtaStatus.INSTALLING ||
  OtaStatus.INSTALLATION_DONE ||
  OtaStatus.CANCELED => null,
};
