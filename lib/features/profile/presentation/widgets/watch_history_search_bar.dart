import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';
import 'package:flutter/material.dart';

/// The watch history search field, a [DpadTextBox]. It redraws itself on
/// focus and typing, so the screen doesn't rebuild for them (REV-97).
class WatchHistorySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final double? width;

  const WatchHistorySearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget field(VoidCallback stopTyping) => TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onEditingComplete: stopTyping,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: AppTheme.accent,
      decoration: InputDecoration(
        hintText: l10n.watchHistorySearchPlaceholder,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );

    return DpadTextBox(
      textFocusNode: focusNode,
      borderRadius: AppTheme.radius12,
      builder: (context, textNode, stopTyping) => ListenableBuilder(
        listenable: Listenable.merge([focusNode, controller]),
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFocused
                    ? AppTheme.accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: isFocused ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: isFocused ? AppTheme.accent : AppTheme.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: child!),
                if (controller.text.trim().isNotEmpty)
                  DpadFocusable(
                    tooltip: l10n.commonClearSearch,
                    onTap: controller.clear,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: field(stopTyping),
      ),
    );
  }
}
