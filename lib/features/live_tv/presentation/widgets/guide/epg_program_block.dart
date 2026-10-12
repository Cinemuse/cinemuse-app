import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/epg_program.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Single interactive program card placed along the horizontal timeline grid.
class EpgProgramBlock extends StatelessWidget {
  final EpgProgram program;
  final Channel channel;
  final double width;
  final bool isLive;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChange;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const EpgProgramBlock({
    super.key,
    required this.program,
    required this.channel,
    required this.width,
    required this.isLive,
    required this.onTap,
    required this.onFocusChange,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    // Minimum comfortable width to render text
    final isCompact = width < 70;
    final isTiny = width < 40;

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 3.0),
        child: DpadFocusable(
          focusNode: focusNode,
          onKeyEvent: onKeyEvent,
          onTap: onTap,
          onFocusChange: onFocusChange,
          borderRadius: BorderRadius.circular(6),
          builder: (context, isFocused, isHovered, _) {
            final isHighlighted = isFocused || isHovered;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: isTiny ? 2 : (isCompact ? 6 : 10),
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.accent.withValues(alpha: 0.28)
                    : (isHovered
                          ? Colors.white.withValues(alpha: 0.12)
                          : (isLive
                                ? AppTheme.secondary
                                : AppTheme.secondary.withValues(alpha: 0.5))),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.accent
                      : (isHovered
                            ? Colors.white.withValues(alpha: 0.3)
                            : (isLive
                                  ? AppTheme.accent.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.07))),
                  width: isFocused ? 1.5 : 1.0,
                ),
                boxShadow: isFocused ? AppTheme.shadowFocusGlow : null,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isTiny) ...[
                        Row(
                          children: [
                            if (isLive && !isCompact) ...[
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                  color: AppTheme.favorites,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                program.name,
                                style: TextStyle(
                                  color: isHighlighted
                                      ? Colors.white
                                      : (isLive
                                            ? AppTheme.textWhite
                                            : AppTheme.textWhite.withValues(
                                                alpha: 0.85,
                                              )),
                                  fontSize: 12,
                                  fontWeight: isLive || isHighlighted
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 2),
                          Text(
                            program.timeRange,
                            style: TextStyle(
                              color: isFocused
                                  ? Colors.white70
                                  : AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ],
                  ),

                  // Bottom progress line for live program
                  if (isLive)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: program.progress,
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFocused ? Colors.white : AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
