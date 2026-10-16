import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/error_action.dart';
import 'package:cinemuse_app/shared/widgets/error_kind_icon.dart';
import 'package:flutter/material.dart';

/// Full-screen error: icon, title, message, then the buttons in this order:
/// [extraActions], Retry ([onRetry]), [mainAction]. The main button
/// ([mainAction], else Retry) takes the focus so a remote can press it at once.
class ErrorViewState extends StatelessWidget {
  final UserFriendlyError error;

  /// Shown above the message; defaults to [UserFriendlyError.title].
  final String? title;
  final VoidCallback? onRetry;
  final ErrorAction? mainAction;
  final List<ErrorAction> extraActions;

  const ErrorViewState({
    super.key,
    required this.error,
    this.title,
    this.onRetry,
    this.mainAction,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = this.title ?? error.title;
    final hint = error.hint;
    final retry = onRetry;
    final main = mainAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(error.kind.icon, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final action in extraActions)
                  _ErrorButton(action: action, isMain: false),
                if (retry != null)
                  _ErrorButton(
                    action: ErrorAction(
                      label: AppLocalizations.of(context)!.commonRetry,
                      icon: Icons.refresh_rounded,
                      onPressed: retry,
                    ),
                    isMain: main == null,
                  ),
                if (main != null) _ErrorButton(action: main, isMain: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorButton extends StatelessWidget {
  final ErrorAction action;
  final bool isMain;

  const _ErrorButton({required this.action, required this.isMain});

  @override
  Widget build(BuildContext context) {
    final icon = action.icon;
    final label = Text(action.label);
    if (isMain) {
      return icon == null
          ? ElevatedButton(
              autofocus: true,
              onPressed: action.onPressed,
              child: label,
            )
          : ElevatedButton.icon(
              autofocus: true,
              onPressed: action.onPressed,
              icon: Icon(icon),
              label: label,
            );
    }
    return icon == null
        ? OutlinedButton(onPressed: action.onPressed, child: label)
        : OutlinedButton.icon(
            onPressed: action.onPressed,
            icon: Icon(icon),
            label: label,
          );
  }
}
