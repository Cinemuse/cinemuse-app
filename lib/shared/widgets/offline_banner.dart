import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';


class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppTheme.getResponsiveHorizontalPadding(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.offlineBannerTitle,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.offlineBannerMessage,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l10n.commonRetry),
            ),
        ],
      ),
    );
  }
}
