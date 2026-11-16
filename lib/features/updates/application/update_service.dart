import 'dart:async';

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:path/path.dart' as p;
import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/data/linux_updater_script.dart';
import 'package:cinemuse_app/features/updates/data/update_archive_extractor.dart';
import 'package:cinemuse_app/features/updates/data/update_checksum.dart';
import 'package:cinemuse_app/features/updates/domain/release_version.dart';
import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/features/updates/data/windows_updater_script.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

// Not autoDispose: the check at app start and a download outlive the
// Settings page that shows them.
final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

/// Release builds only: a debug build carries pubspec's placeholder
/// version, so every release would look newer. Tests override it.
final updatesShownProvider = Provider.autoDispose<bool>((ref) => !kDebugMode);

/// Whether a newer version is out: the message at app start, the dot on
/// the Settings button and the Info & updates page.
final hasUpdateProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(updatesShownProvider) &&
      ref.watch(updateProvider).latestVersion != null,
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

  /// The releases' repo from the server's list, else the built-in one, so
  /// a signed-out first start still finds updates.
  Future<String> _repoAddress() async {
    try {
      return releasesRepo(await ref.read(serverAddressesProvider.future));
    } on AppFailure catch (e) {
      AppLogger.warn(
        _tag,
        'Address list not loaded, using the built-in repo',
        error: e,
      );
      return releasesRepo(ServerAddresses.empty);
    }
  }

  Future<void> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      state = state.copyWith(
        status: UpdateStatus.checking,
        currentVersion: currentVersion,
      );

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isNotEmpty &&
          connectivity.first == ConnectivityResult.none) {
        _fail('updateNetworkError');
        return;
      }

      final repo = await _repoAddress();
      if (!ref.mounted) return;
      final response = await _dio.get('$repo/releases/latest');

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
        // A fresh state: no new version left over from an earlier check.
        state = UpdateState(
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
      return linuxUpdateUrl(assets);
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
    } else {
      // Runs in the background and reports progress through `state`.
      unawaited(_startDesktopUpdate());
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

  /// Windows and Linux: the app replaces its own files in a folder the user
  /// can write to, so neither ever asks for an admin password.
  Future<void> _startDesktopUpdate() async {
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
      final workDir = p.join((await _updateBaseDir()).path, 'cinemuse_update');
      final archive = await _downloadVerifiedArchive(workDir, checksumUrl);
      state = state.copyWith(
        status: UpdateStatus.readyToInstall,
        clearCancelToken: true,
      );
      await _installAndRestart(archive, workDir, appDir);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger.info(_tag, 'Desktop update cancelled');
        return;
      }
      AppLogger.warn(_tag, 'Desktop update download failed', error: e);
      final isMissing = e.response?.statusCode == 404;
      _fail(isMissing ? 'updateSourceError' : 'updateNetworkError');
    } on ValidationFailure catch (e, st) {
      AppLogger.error(_tag, 'Desktop update refused', error: e, stackTrace: st);
      _fail('updateIntegrityError');
    } catch (e, st) {
      AppLogger.error(_tag, 'Desktop update failed', error: e, stackTrace: st);
      _fail('updateFailed');
    }
  }

  /// On Linux the temporary folder is shared by every user of the PC, so
  /// someone else could change the update after its check. The user's own
  /// app data folder is theirs alone.
  Future<Directory> _updateBaseDir() => Platform.isLinux
      ? getApplicationSupportDirectory()
      : getTemporaryDirectory();

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

  /// Downloads the update into a fresh [workDir] and checks it against the
  /// release's `SHA256SUMS`. Throws a [ValidationFailure] if it doesn't match.
  Future<File> _downloadVerifiedArchive(
    String workDir,
    String checksumUrl,
  ) async {
    final dir = Directory(workDir);
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final url = state.downloadUrl!;
    final assetName = Uri.parse(url).pathSegments.last;
    final archive = File(p.join(workDir, assetName));
    final cancelToken = CancelToken();
    state = state.copyWith(cancelToken: cancelToken);

    await _dio.download(
      url,
      archive.path,
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
      file: archive,
      assetName: assetName,
      sha256Sums: sums.data ?? '',
    );
    return archive;
  }

  /// Extracts the update, starts the script that swaps the files once the
  /// app has closed, and closes the app.
  Future<void> _installAndRestart(
    File archive,
    String workDir,
    String appDir,
  ) async {
    final filesDir = p.join(workDir, 'files');
    await extractUpdateArchive(archive.path, filesDir);
    AppLogger.info(_tag, 'Update verified and extracted, restarting');
    if (Platform.isLinux) {
      await _startLinuxUpdater(filesDir, workDir, appDir);
    } else {
      await _startWindowsUpdater(filesDir, workDir, appDir);
    }
    exit(0);
  }

  Future<void> _startWindowsUpdater(
    String filesDir,
    String workDir,
    String appDir,
  ) async {
    final script = File(p.join(workDir, 'updater.bat'));
    await script.writeAsString(
      buildWindowsUpdaterScript(
        appPid: pid,
        sourceDir: filesDir,
        appDir: appDir,
        exePath: Platform.resolvedExecutable,
        workDir: workDir,
        logPath: p.join(p.dirname(workDir), 'cinemuse_update_log.txt'),
      ),
    );
    await startWindowsUpdater(script.path);
  }

  Future<void> _startLinuxUpdater(
    String filesDir,
    String workDir,
    String appDir,
  ) async {
    final script = File(p.join(workDir, 'updater.sh'));
    await script.writeAsString(linuxUpdaterScript);
    await Process.start('sh', [
      script.path,
      '$pid',
      filesDir,
      appDir,
      Platform.resolvedExecutable,
      workDir,
      p.join(p.dirname(workDir), 'cinemuse_update_log.txt'),
    ], mode: ProcessStartMode.detached);
  }
}

/// The Linux update's download link: the compressed folder, which the app can
/// unpack over itself.
@visibleForTesting
String? linuxUpdateUrl(List<dynamic> assets) {
  final asset = assets.firstWhere((a) {
    final name = (a['name'] as String).toLowerCase();
    return name.contains('linux') && name.endsWith('.tar.gz');
  }, orElse: () => null);
  return asset?['browser_download_url'] as String?;
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

/// The GitHub repo whose releases the app installs: the server's when it is
/// a GitHub repo address, else the built-in one. Any other address could
/// hand the app someone else's installer.
@visibleForTesting
String releasesRepo(ServerAddresses addresses) {
  final fromList = addresses.baseUrl(ServerAddress.updateRepo)!;
  final uri = Uri.parse(fromList);
  final isRepo =
      uri.scheme == 'https' &&
      uri.host == 'api.github.com' &&
      uri.pathSegments.length == 3 &&
      uri.pathSegments.first == 'repos' &&
      !uri.hasQuery &&
      !uri.hasFragment;
  if (isRepo) return fromList;
  AppLogger.warn('UpdateService', 'Update address is not a GitHub repo');
  return ServerAddress.updateRepo.builtIn!;
}
