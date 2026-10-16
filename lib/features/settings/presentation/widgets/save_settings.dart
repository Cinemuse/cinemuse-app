import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns a function that saves the settings its change returns
/// (`save((s) => s.copyWith(...))`) and says so in a snackbar if the save
/// fails (REV-78). Built once per section's `build`.
Future<void> Function(UserSettings Function(UserSettings current) change)
settingsSaver(BuildContext context, WidgetRef ref) =>
    (change) => runSettingsSave(
      context,
      ref,
      (settings) => settings.updateSettings(change),
    );

/// Runs [save] and shows "Error saving" if it fails. By then the notifier
/// has already logged the error and put the old values back.
Future<void> runSettingsSave(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(SettingsNotifier settings) save,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Read before any await: the widget may be gone when the save ends.
  final settings = ref.read(settingsProvider.notifier);
  final errorMapper = ref.read(errorMapperProvider);

  try {
    await save(settings);
  } catch (e) {
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: l10n.settingsErrorSaving(errorMapper.map(e).message),
      isError: true,
    );
  }
}
