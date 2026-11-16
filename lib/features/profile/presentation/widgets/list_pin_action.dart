import 'package:cinemuse_app/features/profile/application/pinned_list_ids_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/action_feedback.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pins [listId] to Home or unpins it, then says which; a failed save shows
/// an error instead (the list sheet and the list card menu share it).
Future<void> togglePinWithFeedback(
  BuildContext context,
  WidgetRef ref,
  String listId,
) async {
  final l10n = AppLocalizations.of(context)!;
  final pins = ref.read(pinnedListIdsProvider.notifier);
  final wasPinned = pins.isPinned(listId);
  final isSaved = await runShowingErrors(
    context,
    ref,
    () => pins.togglePin(listId),
  );
  if (!isSaved || !context.mounted) return;
  AppSnackBar.show(
    context,
    message: wasPinned ? l10n.listUnpinnedSuccess : l10n.listPinnedSuccess,
  );
}
