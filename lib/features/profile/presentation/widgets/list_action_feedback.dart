import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs one list change through [UserListsNotifier] and shows a failure as
/// an error snackbar (REV-106). Returns whether the change worked.
Future<bool> runListAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(UserListsNotifier lists) action,
) async {
  // Read before the await: the widget may be gone when it fails.
  final lists = ref.read(userListsProvider.notifier);
  final errorMapper = ref.read(errorMapperProvider);
  try {
    await action(lists);
    return true;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.show(
        context,
        message: errorMapper.map(e).message,
        isError: true,
      );
    }
    return false;
  }
}
