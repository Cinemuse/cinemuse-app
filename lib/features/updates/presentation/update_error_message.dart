import 'package:cinemuse_app/features/updates/domain/update_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// The translated text for the update error in [state] (REV-29). An unknown
/// key falls back to the generic "update failed".
String updateErrorMessage(AppLocalizations l10n, UpdateState state) =>
    switch (state.errorKey) {
      'updateNoCompatibleApk' => l10n.updateNoCompatibleApk(
        state.errorArgs?['abi'] ?? 'unknown',
      ),
      'updateNetworkError' => l10n.updateNetworkError,
      'updateStorageError' => l10n.updateStorageError,
      'updateSourceError' => l10n.updateSourceError,
      'updateIntegrityError' => l10n.updateIntegrityError,
      'updateFolderNotWritable' => l10n.updateFolderNotWritable,
      'updateAlreadyRunning' => l10n.updateAlreadyRunning,
      'updatePermissionDenied' => l10n.updatePermissionDenied,
      _ => l10n.updateFailed,
    };
