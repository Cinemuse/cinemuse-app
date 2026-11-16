import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _choiceAnimation = Duration(milliseconds: 150);

/// One choice of a [SettingsChoiceTile].
class SettingsChoice<T> {
  final T value;
  final String label;

  const SettingsChoice(this.value, this.label);
}

/// The app's languages (English, Italian) as choices, plus "Original"
/// (Japanese) first when [hasOriginal] (anime audio).
List<SettingsChoice<String>> settingsLanguageChoices(
  AppLocalizations l10n, {
  bool hasOriginal = false,
}) => [
  if (hasOriginal) SettingsChoice('ja', l10n.settingsOriginal),
  SettingsChoice('en', l10n.settingsEnglish),
  SettingsChoice('it', l10n.settingsItalian),
];

/// A settings row with a list of choices. The row shows the current one;
/// a tap, a click or Enter opens the list right under the row, pushing the
/// rows below down, and picking one saves it and closes the list. Back
/// closes it too. One list is open at a time.
///
/// On a phone the current choice takes the description's place under the
/// label (the description shows above the open list), so the label keeps
/// the row's whole width; wider screens show both.
class SettingsChoiceTile<T> extends StatefulWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final T value;
  final List<SettingsChoice<T>> choices;
  final ValueChanged<T> onChanged;
  final bool showDivider;

  const SettingsChoiceTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  State<SettingsChoiceTile<T>> createState() => _SettingsChoiceTileState<T>();
}

class _SettingsChoiceTileState<T> extends State<SettingsChoiceTile<T>> {
  /// The row whose list is open: opening one closes the others.
  static final _openRow = ValueNotifier<Object?>(null);

  /// Taller lists (the countries) scroll inside a box this high.
  static const _maxListHeight = 250.0;
  static const _scrollsAbove = 6;

  /// The widest the list gets beside the row's label, on a wide screen.
  static const _maxListWidth = 320.0;

  final _rowFocus = FocusNode();
  final _selectedFocus = FocusNode();
  final _listKey = GlobalKey();

  bool get _isOpen => _openRow.value == this;

  @override
  void initState() {
    super.initState();
    _openRow.addListener(_onOpenRowChanged);
  }

  @override
  void dispose() {
    _openRow.removeListener(_onOpenRowChanged);
    _rowFocus.dispose();
    _selectedFocus.dispose();
    super.dispose();
  }

  void _onOpenRowChanged() {
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_isOpen) {
      _close();
      return;
    }
    _openRow.value = this;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showList());
  }

  /// Scrolls the page just enough to show the whole list. With the keys the
  /// focus goes to the current choice; its own scroll then finds it in a
  /// long list, so the page jumps first instead of animating against it.
  void _showList() {
    final list = _listKey.currentContext;
    if (!mounted || !_isOpen || list == null) return;
    final isKeyInput = FocusRing.isKeyInput.value;
    unawaited(
      Scrollable.ensureVisible(
        list,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: isKeyInput ? Duration.zero : _choiceAnimation,
      ),
    );
    if (isKeyInput) _selectedFocus.requestFocus();
  }

  void _close() {
    // Before the list goes: a focused choice would leave the focus nowhere.
    if (!_rowFocus.hasFocus) _rowFocus.requestFocus();
    _openRow.value = null;
  }

  void _pick(T value) {
    _close();
    if (value != widget.value) widget.onChanged(value);
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = Breakpoints.isCompact(context);
    final current = widget.choices
        .where((c) => c.value == widget.value)
        .firstOrNull
        ?.label;
    final currentText = current == null
        ? null
        : Text(
            current,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          );
    final chevron = AnimatedRotation(
      turns: _isOpen ? 0.25 : 0,
      duration: _choiceAnimation,
      child: const Icon(
        Icons.chevron_right,
        color: AppTheme.textMuted,
        size: 20,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _isOpen ? AppTheme.accent.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsTile(
            label: widget.label,
            description: isCompact ? null : widget.description,
            subtitle: isCompact ? currentText : null,
            icon: widget.icon,
            focusNode: _rowFocus,
            showDivider: false,
            onTap: _toggle,
            trailing: isCompact || currentText == null
                ? chevron
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: currentText,
                      ),
                      const SizedBox(width: 8),
                      chevron,
                    ],
                  ),
          ),
          if (_isOpen) _buildList(isCompact),
          if (widget.showDivider)
            SettingsRowDivider(hasIcon: widget.icon != null),
        ],
      ),
    );
  }

  Widget _buildList(bool isCompact) {
    final choices = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, choice) in widget.choices.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          _ChoiceItem(
            label: choice.label,
            isSelected: choice.value == widget.value,
            focusNode: choice.value == widget.value ? _selectedFocus : null,
            onTap: () => _pick(choice.value),
          ),
        ],
      ],
    );
    final description = widget.description;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onListKey,
      child: Padding(
        key: _listKey,
        // Under the label: past the row's padding, icon and gap.
        padding: EdgeInsets.fromLTRB(widget.icon != null ? 72 : 16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? double.infinity : _maxListWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCompact && description != null) ...[
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.choices.length > _scrollsAbove)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _maxListHeight),
                  child: SingleChildScrollView(child: choices),
                )
              else
                choices,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const _ChoiceItem({
    required this.label,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: radius,
      // The long list clips its edges: the ring goes inside.
      isFocusRingInside: true,
      builder: (context, isFocused, isHovered, child) => AnimatedContainer(
        duration: _choiceAnimation,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: isHovered ? 0.09 : 0.04),
          borderRadius: radius,
          border: Border.all(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: child,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check, color: AppTheme.accent, size: 18),
          ],
        ],
      ),
    );
  }
}
