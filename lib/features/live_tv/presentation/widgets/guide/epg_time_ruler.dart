import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Top horizontal timeline ruler showing 30-minute interval marks and dates.
class EpgTimeRuler extends StatelessWidget {
  final DateTime windowStart;
  final double totalWidth;
  final double pixelsPerHour;
  final int totalHours;
  final double? nowOffset;

  const EpgTimeRuler({
    super.key,
    required this.windowStart,
    required this.totalWidth,
    required this.pixelsPerHour,
    required this.totalHours,
    this.nowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final slotWidth = pixelsPerHour / 2; // 30-minute slot width
    final totalSlots = totalHours * 2;
    final timeFormat = DateFormat('HH:mm');

    return Container(
      height: 42,
      width: totalWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF120B20),
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Stack(
        children: [
          // 30-minute interval slots
          Row(
            children: List.generate(totalSlots, (index) {
              final slotTime =
                  windowStart.add(Duration(minutes: index * 30));
              final isHour = slotTime.minute == 0;
              final isMidnight = isHour && slotTime.hour == 0;

              return Container(
                width: slotWidth,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isHour
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      width: isHour ? 1.0 : 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMidnight) ...[
                      Text(
                        '${DateFormat('E').format(slotTime).toUpperCase()} ',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                    Text(
                      timeFormat.format(slotTime),
                      style: TextStyle(
                        color: isHour
                            ? AppTheme.textWhite
                            : AppTheme.textMuted.withValues(alpha: 0.8),
                        fontSize: isHour ? 13 : 12,
                        fontWeight:
                            isHour ? FontWeight.w700 : FontWeight.w500,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          // "NOW" marker header pill
          if (nowOffset != null && nowOffset! >= 0 && nowOffset! <= totalWidth)
            Positioned(
              left: nowOffset! - 22,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  'NOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
