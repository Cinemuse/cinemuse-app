import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final errorUiProvider = Provider<ErrorUiHandler>((ref) {
  return ErrorUiHandler();
});

class ErrorUiHandler {
  void showError(BuildContext context, dynamic error) {
    String message = 'An unexpected error occurred';
    
    if (error is AppException) {
      message = error.message;
    } else if (error is String) {
      message = error;
    } else if (error != null) {
      message = error.toString();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
