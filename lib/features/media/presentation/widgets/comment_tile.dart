import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/comment.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class CommentTile extends StatefulWidget {
  final Comment comment;
  const CommentTile({super.key, required this.comment});

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isSpoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final isSpoiler = comment.isSpoiler && !_isSpoilerRevealed;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(comment),
          const SizedBox(height: 12),
          if (isSpoiler) _buildSpoilerOverlay(context) else _buildContent(comment),
          if (!isSpoiler) ...[
            const SizedBox(height: 12),
            _buildFooter(comment),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Comment comment) {
    final author = comment.author;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
          backgroundImage: author.avatarUrl != null
              ? CachedNetworkImageProvider(author.avatarUrl!)
              : null,
          child: author.avatarUrl == null
              ? Text(
                  author.username.isNotEmpty ? author.username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.username,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (comment.createdAt != null)
                Text(
                  timeago.format(comment.createdAt!),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (comment.rating != null) _buildRatingBadge(comment.rating!),
      ],
    );
  }

  Widget _buildRatingBadge(double rating) {
    final formattedRating = rating % 1 == 0 ? rating.toInt().toString() : rating.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
          const SizedBox(width: 4),
          Text(
            formattedRating,
            style: DesktopTypography.bodySecondary.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Comment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.title != null && comment.title!.isNotEmpty) ...[
          Text(
            comment.title!,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (comment.text.isNotEmpty)
          Text(
            comment.text,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 14,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  Widget _buildSpoilerOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => setState(() => _isSpoilerRevealed = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppTheme.textWhite.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.commentsSpoilerWarning,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.commentsTapToReveal,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(Comment comment) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        const Icon(Icons.favorite_border, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          '${comment.likeCount}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        if (comment.replyCount > 0) ...[
          const SizedBox(width: 16),
          const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            l10n.tvTimeReplies(comment.replyCount),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
        const Spacer(),
        _buildSourceTag(comment.source),
      ],
    );
  }

  Widget _buildSourceTag(CommentSource source) {
    String label;
    Color color;

    switch (source) {
      case CommentSource.serializd:
        label = 'Serializd';
        color = const Color(0xFF40BCF4);
        break;
      case CommentSource.letterboxd:
        label = 'Letterboxd';
        color = const Color(0xFF00E054);
        break;
      case CommentSource.tmdb:
        label = 'TMDB';
        color = const Color(0xFF01B4E4);
        break;
      case CommentSource.imdb:
        label = 'IMDb';
        color = const Color(0xFFF5C518);
        break;
      case CommentSource.cinemuse:
        label = 'Cinemuse';
        color = AppTheme.accent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
