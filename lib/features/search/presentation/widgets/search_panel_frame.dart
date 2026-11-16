import 'dart:ui';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The blurred backdrop (a click on it closes) and the centred panel
/// with [header] above [body].
class SearchPanelFrame extends StatelessWidget {
  final Animation<double> scale;
  final VoidCallback onClose;
  final Widget header;
  final Widget body;

  const SearchPanelFrame({
    super.key,
    required this.scale,
    required this.onClose,
    required this.header,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ScaleTransition(
                    scale: scale,
                    // Swallows clicks so one inside the panel doesn't close it.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        color: Colors.transparent,
                        child: _panel(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Flexible(
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                minHeight: 200,
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
