import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs [save] and returns the "Error saving" text if it fails, `null` once
/// saved; for a text box that shows it under itself (REV-261). By then the
/// notifier has already put the old value back.
Future<String?> saveLiveTvChangeError(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() save,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Read before any await: the widget may be gone when the save ends.
  final errorMapper = ref.read(errorMapperProvider);

  try {
    await save();
    return null;
  } catch (e) {
    return l10n.settingsErrorSaving(errorMapper.map(e).message);
  }
}

/// Runs [save] and shows "Error saving" if it fails (REV-222, REV-122).
Future<void> saveLiveTvChange(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() save,
) async {
  final error = await saveLiveTvChangeError(context, ref, save);
  if (error == null || !context.mounted) return;
  AppSnackBar.show(context, message: error, isError: true);
}

/// [saveLiveTvChange] for a playlist change.
Future<void> savePlaylists(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(CustomPlaylistsNotifier playlists) save,
) {
  final playlists = ref.read(customPlaylistsProvider.notifier);
  return saveLiveTvChange(context, ref, () => save(playlists));
}
