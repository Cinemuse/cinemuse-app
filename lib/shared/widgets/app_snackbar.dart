import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

class _LiveTimerSnackBarContent extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDesktop;
  final Duration duration;
  final bool showTimer;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool focusesAction;

  const _LiveTimerSnackBarContent({
    required this.message,
    required this.isError,
    required this.isDesktop,
    required this.duration,
    required this.showTimer,
    this.actionLabel,
    this.onAction,
    this.focusesAction = false,
  });

  @override
  State<_LiveTimerSnackBarContent> createState() =>
      _LiveTimerSnackBarContentState();
}

class _LiveTimerSnackBarContentState extends State<_LiveTimerSnackBarContent> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.duration.inSeconds;
    if (widget.showTimer && _secondsLeft > 0) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          timer.cancel();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = widget.actionLabel;
    final onAction = widget.onAction;
    return Row(
      children: [
        Icon(
          widget.isError ? LucideIcons.alertCircle : LucideIcons.info,
          color: widget.isError ? Colors.white : AppTheme.accent,
          size: widget.isDesktop ? 24 : 20,
        ),
        SizedBox(width: widget.isDesktop ? 16 : 12),
        Expanded(
          child: Text(
            widget.showTimer && _secondsLeft > 0
                ? "${widget.message} ($_secondsLeft)"
                : widget.message,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isDesktop ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          _SnackBarButton(
            label: actionLabel,
            color: widget.isError ? Colors.white : AppTheme.accent,
            fontSize: widget.isDesktop ? 16 : 14,
            onPressed: onAction,
            takesFocus: widget.focusesAction,
          ),
      ],
    );
  }
}

/// The message's button, pressable with the arrows and Enter (Flutter's own
/// SnackBarAction has no shared focus ring).
class _SnackBarButton extends StatefulWidget {
  final String label;
  final Color color;
  final double fontSize;
  final VoidCallback onPressed;

  /// Takes the focus when the message shows, if the keyboard or remote was
  /// used last: a remote has no other way to reach a message that closes
  /// in a few seconds.
  final bool takesFocus;

  const _SnackBarButton({
    required this.label,
    required this.color,
    required this.fontSize,
    required this.onPressed,
    required this.takesFocus,
  });

  @override
  State<_SnackBarButton> createState() => _SnackBarButtonState();
}

class _SnackBarButtonState extends State<_SnackBarButton> {
  final _focusNode = FocusNode(debugLabel: 'SnackBar button');

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  @override
  void initState() {
    super.initState();
    if (widget.takesFocus && FocusRing.isKeyInput.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    // When the message closes, Flutter gives the focus back to the item
    // that had it before.
    _focusNode.dispose();
    super.dispose();
  }

  void _giveFocusBack() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus(
        disposition: UnfocusDisposition.previouslyFocusedChild,
      );
    }
  }

  void _press() {
    _giveFocusBack();
    widget.onPressed();
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
  }

  // The arrows go back to the item the user was on, not to whatever lies
  // in that direction from the corner the message sits in.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_arrowKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _giveFocusBack();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: _focusNode,
      onTap: _press,
      onKeyEvent: _onKeyEvent,
      borderRadius: AppTheme.radiusMd,
      // The message clips what lies outside it, and on a phone it leaves
      // too little room around the button for the outer ring.
      isFocusRingInside: true,
      builder: (context, isFocused, isHovered, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isHovered ? AppTheme.accentHoverBg : Colors.transparent,
          borderRadius: AppTheme.radiusMd,
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          widget.label,
          style: TextStyle(
            color: widget.color,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Sits above every screen, sheet and dialog and shows the messages sent
/// from inside a sheet or dialog, which would otherwise be drawn on the
/// screen behind it. The screens keep their own messages (on a phone, above
/// the bottom tab bar) through the second messenger.
class AppSnackBarHost extends StatelessWidget {
  final Widget child;

  const AppSnackBarHost({super.key, required this.child});

  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The screens below move out of the keyboard's way themselves.
        resizeToAvoidBottomInset: false,
        body: ScaffoldMessenger(child: child),
      ),
    );
  }
}

class AppSnackBar {
  /// How long every Undo message stays up: one time for the whole app, set
  /// by the Undo time setting. Zero is Off: no message, the removal is final
  /// at once.
  static Duration undoDuration = defaultUndoDuration;
  static const defaultUndoDuration = Duration(seconds: 4);

  /// "[message] (4) Undo", with a countdown, after something was removed.
  /// Completes when the message closes: true if Undo was pressed.
  static Future<bool> showUndo(
    BuildContext context, {
    required String message,
  }) {
    if (undoDuration == Duration.zero) return Future.value(false);
    return show(
      context,
      message: message,
      actionLabel: AppLocalizations.of(context)!.commonUndo,
      onAction: () {}, // the action only closes the message as "action"
      duration: undoDuration,
      showTimer: true,
      focusesAction: true,
    ).closed.then((reason) => reason == SnackBarClosedReason.action);
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    bool showTimer = false,
    bool focusesAction = false,
    Color? backgroundColor,
    EdgeInsetsGeometry? margin,
  }) {
    // From inside a sheet or dialog: above it, clear of the keyboard.
    final hostMessenger = ModalRoute.of(context) is PopupRoute
        ? AppSnackBarHost._messengerKey.currentState
        : null;
    final scaffoldMessenger = hostMessenger ?? ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    final keyboard = hostMessenger != null
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    final size = MediaQuery.sizeOf(context);
    final isDesktop = !Breakpoints.isCompact(context);

    // Desktop: ~ 1/4th of screen, clamped between 300 and 400.
    final double snackBarWidth = (size.width * 0.25).clamp(300.0, 400.0);

    EdgeInsetsGeometry resolvedMargin;
    if (isDesktop) {
      final double bottomMargin = margin is EdgeInsets ? margin.bottom : 24.0;
      resolvedMargin = EdgeInsets.only(
        left: size.width - snackBarWidth - 24, // 24px from right edge
        right: 24,
        bottom: bottomMargin + keyboard,
      );
    } else {
      resolvedMargin = (margin ?? const EdgeInsets.all(16)).add(
        EdgeInsets.only(bottom: keyboard),
      );
    }

    final effectiveBgColor =
        backgroundColor ??
        (isError
            ? Colors.red.shade800
            : AppTheme.surface.withValues(alpha: 0.95));

    return scaffoldMessenger.showSnackBar(
      SnackBar(
        content: _LiveTimerSnackBarContent(
          message: message,
          isError: isError,
          isDesktop: isDesktop,
          duration: duration,
          showTimer: showTimer,
          actionLabel: actionLabel,
          onAction: onAction,
          focusesAction: focusesAction,
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: effectiveBgColor,
        margin: resolvedMargin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        padding: isDesktop
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 12,
      ),
    );
  }
}
