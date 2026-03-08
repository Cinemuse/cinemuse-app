import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorViewState extends StatelessWidget {
  final String title;
  final String message;
  final String? hint;
  final AppExceptionType type;
  final VoidCallback? onRetry;

  const ErrorViewState({
    super.key,
    required this.title,
    required this.message,
    this.hint,
    this.type = AppExceptionType.unknown,
    this.onRetry,
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
      case AppExceptionType.realtime:
        icon = Icons.sync_problem_rounded;
        color = Colors.tealAccent;
        break;
      default:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with Glow
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 64),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: color.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.2),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color.withOpacity(0.4)),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  "Retry",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
