import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/own_review_text.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/wreath.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Your own review, first in the reviews sheet and set apart from the outside
/// ones: "Your review" instead of a name, and the wreath big enough to count
/// its leaves, with the number inside.
class OwnReviewTile extends StatelessWidget {
  final OwnReview review;

  const OwnReviewTile({super.key, required this.review});

  static const _wreathSize = 96.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = review.text;

    // Pressing it does nothing, but the remote stops on it, so Down goes on
    // to the next review. The ring goes inside: the list clips its sides.
    return DpadFocusable(
      autoScroll: false,
      borderRadius: AppTheme.radius12,
      isFocusRingInside: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppTheme.accent.withValues(alpha: 0.08),
            AppTheme.surface,
          ),
          borderRadius: AppTheme.radius12,
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.ownReviewEditorTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // When it last changed.
                Text(
                  timeago.format(review.updatedAt),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Wreath(
                score: review.rating,
                size: _wreathSize,
                showNumber: true,
              ),
            ),
            if (text != null) ...[
              const SizedBox(height: 12),
              OwnReviewText(text),
            ],
          ],
        ),
      ),
    );
  }
}
