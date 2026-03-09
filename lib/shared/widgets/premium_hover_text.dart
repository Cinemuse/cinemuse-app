import 'dart:async';
import 'package:flutter/material.dart';

class PremiumHoverText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final Duration delay;
  final TextAlign textAlign;
  final double width;

  const PremiumHoverText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.delay = const Duration(seconds: 1),
    this.textAlign = TextAlign.start,
    this.width = double.infinity,
  });

  @override
  State<PremiumHoverText> createState() => _PremiumHoverTextState();
}

class _PremiumHoverTextState extends State<PremiumHoverText> {
  bool _isHovered = false;
  Timer? _debounceTimer;

  void _onEnter(PointerEvent details) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.delay, () {
      if (mounted) {
        setState(() => _isHovered = true);
      }
    });
  }

  void _onExit(PointerEvent details) {
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() => _isHovered = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: widget.width,
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: _isHovered ? null : widget.maxLines,
            overflow: _isHovered ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
