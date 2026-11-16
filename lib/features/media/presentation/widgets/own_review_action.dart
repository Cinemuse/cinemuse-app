import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Under the reviews sheet's title: the button that opens the editor, or, on a
/// title not watched yet, the line saying why there is none (a line the remote
/// skips). Nothing while that isn't known yet.
class OwnReviewAction extends ConsumerWidget {
  final RatedTitle title;
  final FocusNode focusNode;
  final VoidCallback onEdit;

  const OwnReviewAction({
    super.key,
    required this.title,
    required this.focusNode,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final canRate = ref.watch(canRateTitleProvider(title));
    if (canRate == null) return const SizedBox.shrink();
    if (!canRate) return _NotWatchedLine(text: l10n.ownReviewNotWatched);

    final review = ref.watch(ownReviewProvider(title));
    if (review.hasError && !review.hasValue) {
      return _LoadError(
        focusNode: focusNode,
        onRetry: () => ref.invalidate(ownReviewProvider(title)),
      );
    }
    if (!review.hasValue) return const SizedBox.shrink();
    return _EditButton(
      focusNode: focusNode,
      label: review.value == null ? l10n.ownReviewAdd : l10n.ownReviewEdit,
      onTap: onEdit,
    );
  }
}

class _NotWatchedLine extends StatelessWidget {
  final String text;

  const _NotWatchedLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Wreath(score: 0, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;

  const _EditButton({
    required this.focusNode,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: AppTheme.radius12,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.textWhite.withValues(alpha: 0.08),
          borderRadius: AppTheme.radius12,
          border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppTheme.textWhite,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onRetry;

  const _LoadError({required this.focusNode, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.ownReviewLoadError,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        DpadFocusable(
          focusNode: focusNode,
          onTap: onRetry,
          borderRadius: AppTheme.radius12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              l10n.commonRetry,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
