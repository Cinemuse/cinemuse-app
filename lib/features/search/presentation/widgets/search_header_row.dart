import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/search/presentation/widgets/search_hover_button.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// The search overlay's top line: Back, the search box, Clear and the
/// loading spinner. Left / Right move between them; Down goes to the content.
class SearchHeaderRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode inputFocusNode;
  final FocusNode backFocusNode;
  final FocusNode clearFocusNode;
  final bool isOffline;
  final bool isLoading;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final VoidCallback onFocusContent;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const SearchHeaderRow({
    super.key,
    required this.controller,
    required this.inputFocusNode,
    required this.backFocusNode,
    required this.clearFocusNode,
    required this.isOffline,
    required this.isLoading,
    required this.onClose,
    required this.onClear,
    required this.onFocusContent,
    required this.onChanged,
    required this.onSubmitted,
  });

  /// Handles Down (to the content) and [sideKey] (back to the search box).
  FocusOnKeyEventCallback _buttonKeys(LogicalKeyboardKey sideKey) {
    return (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == sideKey) {
        inputFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        onFocusContent();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inputStyle = TextStyle(
      fontSize: 20,
      color: isOffline ? AppTheme.textMuted : Colors.white,
      fontWeight: FontWeight.w300,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          SearchHoverButton(
            focusNode: backFocusNode,
            onTap: onClose,
            onKeyEvent: _buttonKeys(LogicalKeyboardKey.arrowRight),
            tooltip: l10n.commonCancel,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                LucideIcons.arrowLeft,
                color: AppTheme.textWhite,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isOffline,
              focusNode: inputFocusNode,
              cursorColor: Colors.white,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: inputStyle,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                hintStyle: inputStyle.copyWith(
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hoverColor: Colors.transparent,
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            SearchHoverButton(
              focusNode: clearFocusNode,
              onTap: onClear,
              onKeyEvent: _buttonKeys(LogicalKeyboardKey.arrowLeft),
              tooltip: l10n.commonClearAll,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(LucideIcons.x, color: AppTheme.textWhite, size: 18),
              ),
            ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
