import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Deletes [list] with an Undo snackbar (Home and Profile share it). The
/// list hides at once; if the delete fails it comes back with a message.
Future<void> deleteListWithUndo(
  BuildContext context,
  WidgetRef ref,
  UserList list,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Read before any await: the widget may be gone when the snackbar closes.
  final notifier = ref.read(userListsProvider.notifier);
  final errorMapper = ref.read(errorMapperProvider);

  final undone = AppSnackBar.showUndo(
    context,
    message: l10n.detailsListDeleted(list.name),
  );

  try {
    await notifier.deleteWithUndo(list.id, undone: undone);
  } catch (e) {
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      message: errorMapper.map(e).message,
      isError: true,
    );
  }
}
