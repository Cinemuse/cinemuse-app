import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The tabs of the player's tracks panel.
enum PlayerSettingsTab { audio, subtitles, look }

/// The row of tabs on top of the player's settings panel. Left / Right
/// switch tab at once, without OK, and never leave the row.
class SettingsTabBar extends StatelessWidget {
  final PlayerSettingsTab selected;

  /// One per tab, in [PlayerSettingsTab] order: the panel sends the focus
  /// back to the selected tab.
  final List<FocusNode> focusNodes;
  final ValueChanged<PlayerSettingsTab> onSelect;

  const SettingsTabBar({
    super.key,
    required this.selected,
    required this.focusNodes,
    required this.onSelect,
  });

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final next = selected.index + step;
    if (next >= 0 && next < PlayerSettingsTab.values.length) {
      onSelect(PlayerSettingsTab.values[next]);
      focusNodes[next].requestFocus();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(event),
      child: Row(
        children: [
          for (final tab in PlayerSettingsTab.values)
            Expanded(
              child: _Tab(
                label: switch (tab) {
                  PlayerSettingsTab.audio => l10n.playerAudio,
                  PlayerSettingsTab.subtitles => l10n.playerSubtitles,
                  PlayerSettingsTab.look => l10n.playerLookTab,
                },
                isSelected: tab == selected,
                focusNode: focusNodes[tab.index],
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: AppTheme.radiusMd,
      builder: (context, isFocused, isHovered, _) {
        final color = isSelected
            ? AppTheme.accent
            : (isFocused || isHovered)
            ? AppTheme.textWhite
            : AppTheme.textMuted;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : Colors.transparent,
                  borderRadius: AppTheme.radiusFull,
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
