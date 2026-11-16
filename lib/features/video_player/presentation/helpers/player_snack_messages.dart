import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';

/// What the player's short messages are built from.
typedef PlayerMessageState = ({String? error, String? notice});

const _margin = EdgeInsets.only(bottom: 80, left: 16, right: 16);

/// Shows the player's bottom messages that [next] brings and [previous]
/// didn't: an error or a notice.
void showPlayerSnackMessages(
  BuildContext context, {
  required PlayerMessageState? previous,
  required PlayerMessageState next,
}) {
  final error = next.error;
  if (error != null && error != previous?.error) {
    AppSnackBar.show(
      context,
      message: error,
      backgroundColor: Theme.of(context).colorScheme.error,
      margin: _margin,
    );
  }

  final notice = next.notice;
  if (notice != null && notice != previous?.notice) {
    AppSnackBar.show(
      context,
      message: notice,
      backgroundColor: AppTheme.secondary,
      duration: const Duration(seconds: 3),
      margin: _margin,
    );
  }
}
