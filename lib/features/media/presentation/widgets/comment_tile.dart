import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/domain/tvtime_comment.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentTile extends StatefulWidget {
  final TvTimeComment comment;
  const CommentTile({
    super.key,
    required this.comment,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isSpoilerRevealed = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final user = comment.user;
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
          _buildHeader(user, comment.createdAt),
          const SizedBox(height: 12),
          if (isSpoiler)
            _buildSpoilerOverlay()
          else
            _buildContent(comment),
          if (!isSpoiler) ...[
            const SizedBox(height: 12),
            _buildFooter(comment),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(TvTimeUser? user, DateTime? createdAt) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
          backgroundImage: user?.avatarUrl != null
              ? CachedNetworkImageProvider(user!.avatarUrl!)
              : null,
          child: user?.avatarUrl == null
              ? Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? 'Anonymous',
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (createdAt != null)
                Text(
                  timeago.format(createdAt),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(TvTimeComment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comment.text.isNotEmpty)
          Text(
            comment.text,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        if (comment.imageUrl != null) ...[
          if (comment.text.isNotEmpty) const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: comment.imageWidth != null && comment.imageHeight != null
                ? AspectRatio(
                    aspectRatio: comment.imageWidth! / comment.imageHeight!,
                    child: _buildCachedNetworkImage(comment.imageUrl!),
                  )
                : _buildCachedNetworkImage(comment.imageUrl!),
          ),
        ],
      ],
    );
  }

  Widget _buildCachedNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppTheme.textWhite.withValues(alpha: 0.05),
        height: 200,
        width: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
  Widget _buildSpoilerOverlay() {
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
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Spoiler Warning',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to reveal',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(TvTimeComment comment) {
    return Row(
      children: [
        const Icon(Icons.favorite_border, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          '${comment.likeCount}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const Spacer(),
        if (comment.reportCount > 0) ...[
          Icon(Icons.flag_outlined, size: 16, color: Colors.redAccent.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            '${comment.reportCount}',
            style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      ],
    );
  }
}
