import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class _LiveTimerSnackBarContent extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDesktop;
  final Duration duration;
  final bool showTimer;

  const _LiveTimerSnackBarContent({
    required this.message,
    required this.isError,
    required this.isDesktop,
    required this.duration,
    required this.showTimer,
  });

  @override
  State<_LiveTimerSnackBarContent> createState() => _LiveTimerSnackBarContentState();
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
            widget.showTimer && _secondsLeft > 0 ? "${widget.message} ($_secondsLeft)" : widget.message,
            style: TextStyle(
              color: Colors.white, 
              fontSize: widget.isDesktop ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class AppSnackBar {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    bool showTimer = false,
    Color? backgroundColor,
    EdgeInsetsGeometry? margin,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width > 800;
    
    // Desktop: ~ 1/4th of screen, clamped between 300 and 400.
    final double snackBarWidth = (size.width * 0.25).clamp(300.0, 400.0);
    
    EdgeInsetsGeometry resolvedMargin;
    if (isDesktop) {
      final double bottomMargin = margin is EdgeInsets ? margin.bottom : 24.0;
      resolvedMargin = EdgeInsets.only(
        left: size.width - snackBarWidth - 24, // 24px from right edge
        right: 24,
        bottom: bottomMargin,
      );
    } else {
      resolvedMargin = margin ?? const EdgeInsets.all(16);
    }

    final effectiveBgColor = backgroundColor ?? (isError ? Colors.red.shade800 : AppTheme.surface.withValues(alpha: 0.95));

    return scaffoldMessenger.showSnackBar(
      SnackBar(
        content: _LiveTimerSnackBarContent(
          message: message,
          isError: isError,
          isDesktop: isDesktop,
          duration: duration,
          showTimer: showTimer,
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: isError ? Colors.white : AppTheme.accent,
                onPressed: onAction,
              )
            : null,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: effectiveBgColor,
        margin: resolvedMargin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
        ),
        padding: isDesktop 
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 12,
      ),
    );
  }
}
