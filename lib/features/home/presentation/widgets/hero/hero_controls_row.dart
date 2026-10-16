import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_indicator_dot.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The hero's page dots, plus the pause / resume button on phones (wide
/// screens pause while the hero has the focus).
class HeroControlsRow extends StatelessWidget {
  final int total;
  final int currentIndex;
  final bool isMobile;
  final bool isWidescreen;
  final bool isAutoPlayEnabled;
  final ValueChanged<int> onDotTap;
  final VoidCallback onToggleAutoPlay;

  const HeroControlsRow({
    super.key,
    required this.total,
    required this.currentIndex,
    required this.isMobile,
    required this.isWidescreen,
    required this.isAutoPlayEnabled,
    required this.onDotTap,
    required this.onToggleAutoPlay,
  });

  @override
  Widget build(BuildContext context) {
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < total; index++)
          HeroIndicatorDot(
            isActive: index == currentIndex,
            isMobile: isMobile,
            onTap: () => onDotTap(index),
          ),
      ],
    );
    if (isWidescreen) return dots;

    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        dots,
        const SizedBox(width: 4),
        IconButton(
          tooltip: isAutoPlayEnabled
              ? l10n.homeHeroPauseCarousel
              : l10n.homeHeroResumeCarousel,
          onPressed: onToggleAutoPlay,
          iconSize: isMobile ? 20 : 22,
          color: AppTheme.textWhite.withValues(alpha: 0.85),
          icon: Icon(
            isAutoPlayEnabled ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
      ],
    );
  }
}
