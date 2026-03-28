import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorCard extends StatelessWidget {
  final String message;
  final String? hint;
  final AppExceptionType type;
  final VoidCallback? onRetry;

  const ErrorCard({
    super.key,
    required this.message,
    this.hint,
    this.type = AppExceptionType.unknown,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case AppExceptionType.network:
        color = Colors.orangeAccent;
        break;
      case AppExceptionType.streaming:
        color = Colors.blueAccent;
        break;
      case AppExceptionType.realtime:
        color = Colors.tealAccent;
        break;
      default:
        color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, color: color, size: 20),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
