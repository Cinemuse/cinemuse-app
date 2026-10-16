import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/error_action.dart';
import 'package:cinemuse_app/shared/widgets/error_kind_icon.dart';
import 'package:flutter/material.dart';

/// Inline error inside a screen (a row, a panel): icon, message, a text Retry
/// button and an optional [extraAction]. [autofocus] gives Retry the focus;
/// leave it off where the card sits among other content (Home rows).
class ErrorCard extends StatelessWidget {
  final UserFriendlyError error;
  final VoidCallback? onRetry;
  final ErrorAction? extraAction;
  final bool autofocus;

  const ErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.extraAction,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = error.hint;
    final retry = onRetry;
    final extra = extraAction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: AppTheme.radius12,
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(error.kind.icon, color: AppTheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.message,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (extra != null)
            TextButton(onPressed: extra.onPressed, child: Text(extra.label)),
          if (retry != null)
            TextButton.icon(
              autofocus: autofocus,
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.commonRetry),
            ),
        ],
      ),
    );
  }
}
