import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class SettingToggle extends StatelessWidget {
  final String? label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingToggle({
    super.key,
    this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final toggle = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 22,
          decoration: BoxDecoration(
            color: value ? AppTheme.accent : Colors.white.withOpacity(0.1),
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
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                    ),
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
