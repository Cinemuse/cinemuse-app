import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';

/// Top details banner in the EPG TV Guide displaying the currently focused
/// program's title, synopsis, progress and channel details.
///
/// It has nothing the arrows reach: they move between the top bar and the
/// guide. Its star is for the mouse; with a remote, holding Enter on a
/// channel in the guide does the same.
class EpgDetailsBanner extends StatelessWidget {
  final Channel? channel;
  final EpgProgram? program;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const EpgDetailsBanner({
    super.key,
    required this.channel,
    required this.program,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final isLive = program?.isLive ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface.withValues(alpha: 0.85),
            AppTheme.secondary.withValues(alpha: 0.90),
          ],
        ),
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMetaBadges(context, l10n, isLive),
          const SizedBox(height: 8),
          _buildTitle(),
          const SizedBox(height: 6),
          _buildDescription(l10n),
          if (isLive && program != null) ...[
            const SizedBox(height: 10),
            _buildProgressBar(context, l10n, now),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaBadges(
    BuildContext context,
    AppLocalizations l10n,
    bool isLive,
  ) {
    return Row(
      children: [
        if (channel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (channel!.lcn > 0) ...[
                  Text(
                    '${channel!.lcn}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  channel!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onToggleFavorite != null) ...[
            const SizedBox(width: 6),
            _buildFavoriteStar(l10n),
          ],
          const SizedBox(width: 10),
        ],
        if (isLive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.favorites.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.favorites.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.liveTvLive.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (program != null) ...[
          Text(
            program!.timeRange,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitle() {
    final title = program?.name ?? channel?.name ?? '';
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textWhite,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontFamily: 'Outfit',
        letterSpacing: 0.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDescription(AppLocalizations l10n) {
    final desc =
        program?.description ??
        program?.subtitle ??
        l10n.liveTvNoProgramDetails;

    return Text(
      desc,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
        height: 1.35,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    AppLocalizations l10n,
    DateTime now,
  ) {
    final progress = program!.progress;
    final remainingMinutes = program!.endTime
        .difference(now)
        .inMinutes
        .clamp(0, 9999);

    return Row(
      children: [
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          l10n.liveTvMinutesRemaining(remainingMinutes),
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// A mouse click only: not a stop for the arrows (see the class).
  Widget _buildFavoriteStar(AppLocalizations l10n) {
    return Tooltip(
      message: isFavorite
          ? l10n.liveTvRemoveFromFavorites
          : l10n.liveTvAddToFavorites,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onToggleFavorite,
          child: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFavorite ? Colors.amber : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }
}
