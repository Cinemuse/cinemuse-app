import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Top details banner in the EPG TV Guide displaying the currently focused
/// program's title, synopsis, progress, channel details, and quick play action.
class EpgDetailsBanner extends StatelessWidget {
  final Channel? channel;
  final EpgProgram? program;
  final bool isFavorite;
  final VoidCallback? onWatch;
  final VoidCallback? onToggleFavorite;

  const EpgDetailsBanner({
    super.key,
    required this.channel,
    required this.program,
    this.isFavorite = false,
    this.onWatch,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final isLive = program?.isLive ?? false;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surface.withValues(alpha: 0.85),
                const Color(0xFF160D27).withValues(alpha: 0.90),
              ],
            ),
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Details info
              Expanded(
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
              ),
              const SizedBox(width: 24),
              // Right: Actions & Clock
              _buildActions(context, l10n),
            ],
          ),
        ),
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
          const SizedBox(width: 10),
        ],
        if (isLive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE50914).withValues(alpha: 0.4),
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
    final desc = program?.description ??
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
    final remainingMinutes =
        program!.endTime.difference(now).inMinutes.clamp(0, 9999);

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

  Widget _buildActions(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleFavorite != null && channel != null) ...[
              DpadFocusable(
                borderRadius: BorderRadius.circular(10),
                onTap: onToggleFavorite,
                builder: (context, isFocused, isHovered, _) {
                  return Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: isFocused
                          ? Colors.white.withValues(alpha: 0.18)
                          : (isHovered
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: isFocused ? AppTheme.shadowFocusGlow : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isFavorite ? Colors.amber : Colors.white70,
                      size: 22,
                    ),
                  );
                },
                child: const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
            ],
            if (onWatch != null && channel != null)
              DpadFocusable(
                borderRadius: BorderRadius.circular(10),
                onTap: onWatch,
                builder: (context, isFocused, isHovered, _) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isFocused
                          ? AppTheme.accentHover
                          : (isHovered
                              ? AppTheme.accent.withValues(alpha: 0.9)
                              : AppTheme.accent),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isFocused ? AppTheme.shadowFocusGlow : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.liveTvWatchChannel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }
}
