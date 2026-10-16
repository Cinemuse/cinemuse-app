import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/updates/data/app_config_repository.dart';
import 'package:cinemuse_app/features/updates/domain/release_version.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version and build number.
// Not autoDispose: the installed version can't change while the app runs.
final installedVersionProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Whether the installed app is older than the database's minimum version,
/// so it must be updated before it can be used (REV-306).
// Not autoDispose: checked once per session, at startup.
final updateRequiredProvider = FutureProvider<bool>((ref) async {
  final installed = await ref.watch(installedVersionProvider.future);
  final String? minimum;
  try {
    minimum = await ref
        .read(appConfigRepositoryProvider)
        .getMinimumAppVersion();
  } on AppFailure catch (e) {
    // Offline or unreadable: let the app start. Blocking here would lock the
    // user out of a working app (and out of offline use) over a check.
    AppLogger.warn('UpdateRequired', 'Minimum version not read', error: e);
    return false;
  }
  if (minimum == null) return false;
  final isRequired = isBelowMinimumVersion(
    minimum,
    installed.version,
    installed.buildNumber,
  );
  if (isRequired) {
    AppLogger.info(
      'UpdateRequired',
      'Installed ${installed.version}+${installed.buildNumber} '
          'is below the minimum $minimum',
    );
  }
  return isRequired;
});
