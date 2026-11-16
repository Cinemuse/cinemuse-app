import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/shared/widgets/action_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs one list change through [UserListsNotifier] and shows a failure as
/// an error snackbar (REV-106). Returns whether the change worked.
Future<bool> runListAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(UserListsNotifier lists) action,
) {
  // Read before the await: the widget may be gone when it fails.
  final lists = ref.read(userListsProvider.notifier);
  return runShowingErrors(context, ref, () => action(lists));
}
