import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

/// Modern frosted badge displayed at the center of the video player
/// when seeking forward or backward.
class SeekFeedbackHud extends StatelessWidget {
  final int seekAmount;

  const SeekFeedbackHud({
    super.key,
    required this.seekAmount,
  });

  @override
  Widget build(BuildContext context) {
    if (seekAmount == 0) return const SizedBox.shrink();

    final isForward = seekAmount > 0;

    return Center(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: AppTheme.radiusXl,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOverlay,
                  borderRadius: AppTheme.radiusXl,
                  border: Border.all(
                    color: AppTheme.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: AppTheme.shadowNeonSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward
                          ? Icons.fast_forward_rounded
                          : Icons.fast_rewind_rounded,
                      color: AppTheme.textWhite,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isForward ? '+$seekAmount' 's' : '$seekAmount' 's',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
