import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Awaits one user action (a notifier call) and shows a failure as an error
/// snackbar with the mapped, translated text. Returns whether it worked.
/// The notifier has already put the old state back by then.
Future<bool> runShowingErrors(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  // Read before the await: the widget may be gone when it fails.
  final errorMapper = ref.read(errorMapperProvider);
  try {
    await action();
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
