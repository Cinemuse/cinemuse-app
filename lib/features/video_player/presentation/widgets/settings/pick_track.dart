import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';

/// Runs the controller's [pick] and shows [failedMessage] if it fails. The
/// controller has already logged the error.
Future<void> pickTrack(
  BuildContext context,
  Future<void> Function() pick, {
  required String failedMessage,
}) async {
  try {
    await pick();
  } on AppFailure {
    if (context.mounted) {
      AppSnackBar.show(context, message: failedMessage, isError: true);
    }
  }
}
