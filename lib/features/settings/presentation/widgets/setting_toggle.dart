import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// A settings row that is one switch: a click, tap or Enter anywhere on
/// the row flips it, and the row is the one focus stop (REV-84b).
class SettingsToggleTile extends StatelessWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final bool value;

  /// Null locks the row: switch dimmed, can't be focused or tapped.
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final int descriptionMaxLines;

  const SettingsToggleTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
    this.descriptionMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SettingsTile(
      label: label,
      description: description,
      descriptionMaxLines: descriptionMaxLines,
      icon: icon,
      showDivider: showDivider,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: SettingSwitch(value: value, isEnabled: onChanged != null),
    );
  }
}

/// A switch on its own, for a row that isn't a [SettingsTile] (the live TV
/// playlist rows): the switch itself takes the focus and the tap.
class SettingToggle extends StatelessWidget {
  final bool value;

  /// Null locks the switch: drawn dimmed, can't be focused or tapped.
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;

  const SettingToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    if (onChanged == null) {
      return SettingSwitch(value: value, isEnabled: false);
    }
    return DpadFocusable(
      focusNode: focusNode,
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(11),
      scale: 1.05,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SettingSwitch(value: value),
      ),
    );
  }
}

/// The switch's look only: whatever holds it takes the focus and the tap.
class SettingSwitch extends StatelessWidget {
  final bool value;
  final bool isEnabled;

  const SettingSwitch({super.key, required this.value, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 22,
      decoration: BoxDecoration(
        color: value ? AppTheme.accent : Colors.white.withValues(alpha: 0.1),
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
    );
    return isEnabled ? track : Opacity(opacity: 0.4, child: track);
  }
}
