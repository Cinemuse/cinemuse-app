import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/live_tv/application/custom_playlists_notifier.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs [save] and shows "Error saving" if it fails (REV-222). By then the
/// notifier has already put the old list back.
Future<void> savePlaylists(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(CustomPlaylistsNotifier playlists) save,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Read before any await: the widget may be gone when the save ends.
  final playlists = ref.read(customPlaylistsProvider.notifier);
  final errorMapper = ref.read(errorMapperProvider);

  try {
    await save(playlists);
  } catch (e) {
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: l10n.settingsErrorSaving(errorMapper.map(e).message),
      isError: true,
    );
  }
}
