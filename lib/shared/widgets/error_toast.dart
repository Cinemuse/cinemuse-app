import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorToast extends StatelessWidget {
  final String message;
  final AppExceptionType type;
  final VoidCallback onDismiss;

  const ErrorToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case AppExceptionType.network:
        icon = Icons.wifi_off_rounded;
        color = Colors.orangeAccent;
        break;
      case AppExceptionType.streaming:
        icon = Icons.movie_filter_rounded;
        color = Colors.blueAccent;
        break;
      case AppExceptionType.auth:
        icon = Icons.lock_person_rounded;
        color = Colors.purpleAccent;
        break;
      default:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
