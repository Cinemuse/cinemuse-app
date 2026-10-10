import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimise / maximise / close buttons for the frameless desktop window.
class AppWindowButtons extends StatefulWidget {
  const AppWindowButtons({super.key});

  @override
  State<AppWindowButtons> createState() => _AppWindowButtonsState();
}

class _AppWindowButtonsState extends State<AppWindowButtons>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowButton(
          type: _WindowButtonType.minimize,
          onTap: windowManager.minimize,
        ),
        _WindowButton(
          type: _isMaximized
              ? _WindowButtonType.restore
              : _WindowButtonType.maximize,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          type: _WindowButtonType.close,
          onTap: windowManager.close,
        ),
      ],
    );
  }
}

enum _WindowButtonType { minimize, maximize, restore, close }

class _WindowButton extends StatelessWidget {
  final _WindowButtonType type;
  final VoidCallback onTap;

  const _WindowButton({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isClose = type == _WindowButtonType.close;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isClose
            ? const Color(0xFFE81123) // Standard close red
            : Colors.white.withValues(alpha: 0.1),
        child: SizedBox(
          width: 46, // Standard title bar button width
          child: Center(child: _buildIcon()),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (type) {
      case _WindowButtonType.minimize:
        return Container(width: 10, height: 1, color: Colors.white);
      case _WindowButtonType.maximize:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
      case _WindowButtonType.restore:
        return SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(painter: _RestoreIconPainter()),
        );
      case _WindowButtonType.close:
        return SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(painter: _CloseIconPainter()),
        );
    }
  }
}

class _RestoreIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Back square (offset top-right)
    canvas.drawRect(
      Rect.fromLTWH(2, 0, size.width - 2, size.height - 2),
      paint,
    );
    // Front square (bottom-left)
    canvas.drawRect(
      Rect.fromLTWH(0, 2, size.width - 2, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloseIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
