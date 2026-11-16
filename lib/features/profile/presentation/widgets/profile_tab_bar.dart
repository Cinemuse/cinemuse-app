import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

/// The Profile tab names (Overview · Collections). Plain [DpadFocusable]s
/// rather than a Material [TabBar]: the page holds no tab views to slide,
/// and each tab gets the app's focus ring (REV-239).
class ProfileTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// One per tab, so the page can send the focus to the selected one.
  final List<FocusNode> focusNodes;
  final FocusOnKeyEventCallback? onKeyEvent;

  const ProfileTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.focusNodes,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    // Wraps rather than overflows with large text on a narrow phone.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        children: [
          for (var i = 0; i < labels.length; i++)
            _ProfileTab(
              label: labels[i],
              isSelected: i == selectedIndex,
              focusNode: focusNodes[i],
              onKeyEvent: onKeyEvent,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback onTap;

  const _ProfileTab({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onTap: onTap,
      borderRadius: AppTheme.radiusSm,
      builder: (context, isFocused, isHovered, child) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        // As wide as the label: a centring box alone fills the whole row,
        // and the tabs stacked one per line (REV-322).
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              // Like other clickable text with no background, it turns pink.
              color: isSelected
                  ? AppTheme.textWhite
                  : isFocused || isHovered
                  ? AppTheme.accent
                  : AppTheme.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      child: const SizedBox.shrink(),
    );
  }
}
