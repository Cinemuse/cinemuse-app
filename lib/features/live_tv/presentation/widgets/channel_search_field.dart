import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_text_box.dart';

/// The channel search box of the channel list, the drawer over the player
/// and the guide. They share one search, so a search set in one shows in all.
/// The arrows and Enter work as on every [DpadTextBox].
class ChannelSearchField extends ConsumerStatefulWidget {
  /// The box as an arrow stop, so the row around it can focus it.
  final FocusNode? focusNode;

  /// The drawer over the player: Back and Right on the box close it.
  final VoidCallback? onClose;

  /// Up from the box; without it, focus moves to what is above.
  final VoidCallback? onUp;

  /// Down from the box; without it, focus moves to what is below.
  final VoidCallback? onDown;

  /// Left from the box; without it, focus moves to what is beside.
  final VoidCallback? onLeft;

  /// Right from the box; without it, focus moves to what is beside.
  final VoidCallback? onRight;

  /// The search was set from outside the box (a sport card on Home).
  final ValueChanged<String>? onOutsideSearch;

  const ChannelSearchField({
    super.key,
    this.focusNode,
    this.onClose,
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.onOutsideSearch,
  });

  @override
  ConsumerState<ChannelSearchField> createState() => _ChannelSearchFieldState();
}

class _ChannelSearchFieldState extends ConsumerState<ChannelSearchField> {
  late final TextEditingController _controller;
  final _ownBoxNode = FocusNode(debugLabel: 'LiveTvSearchBox');
  Timer? _debounce;

  FocusNode get _boxNode => widget.focusNode ?? _ownBoxNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(channelSearchQueryProvider),
    );
    // Rebuild so the border follows the focus (REV-139).
    _boxNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ChannelSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBoxNode = oldWidget.focusNode ?? _ownBoxNode;
    if (oldBoxNode != _boxNode) {
      oldBoxNode.removeListener(_onFocusChange);
      _boxNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _boxNode.removeListener(_onFocusChange);
    _ownBoxNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  // Waits a moment, so big playlists don't re-filter on every key.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(channelSearchQueryProvider.notifier).set(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(channelSearchQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen<String>(channelSearchQueryProvider, (_, next) {
      if (_controller.text == next) return;
      _debounce?.cancel();
      _controller.text = next;
      _controller.selection = TextSelection.collapsed(offset: next.length);
      widget.onOutsideSearch?.call(next);
    });

    final radius = BorderRadius.circular(10);
    final onClose = widget.onClose;
    return DpadTextBox(
      focusNode: _boxNode,
      onBack: onClose,
      onUp: widget.onUp,
      onDown: widget.onDown,
      onLeft: widget.onLeft,
      onRight: onClose ?? widget.onRight,
      borderRadius: radius,
      builder: (context, textNode, stopTyping) => Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: radius,
          border: Border.all(
            color: _boxNode.hasFocus
                ? AppTheme.accent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: textNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          // Instead of onSubmitted, which would also drop the focus.
          onEditingComplete: stopTyping,
          decoration: InputDecoration(
            hintText: l10n.liveTvSearchPlaceholder,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: Colors.white38,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: l10n.commonClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white38,
                      ),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      onPressed: _clear,
                    ),
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
