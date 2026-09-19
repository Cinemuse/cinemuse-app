import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class SettingToggle extends StatelessWidget {
  final String? label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final FocusNode? focusNode;

  const SettingToggle({
    super.key,
    this.label,
    this.description,
    required this.value,
    required this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final toggle = DpadFocusable(
      focusNode: focusNode,
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(11),
      scale: 1.05,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 22,
          decoration: BoxDecoration(
            color: value
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: value ? 24 : 2,
                top: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (label == null) return toggle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          toggle,
        ],
      ),
    );
  }
}
