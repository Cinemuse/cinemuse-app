import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final Color backgroundColor;
  final Border? border;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.blurSigma = 0.0,
    this.backgroundColor = AppTheme.primary,
    this.border,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
    this.padding = const EdgeInsets.only(top: 16),
    this.showHandle = true,
  });

  /// Standardized helper for showing the bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double? heightFactor,
    BoxConstraints? constraints,
    Color barrierColor = Colors.black54,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
  }) {
    final width = MediaQuery.of(context).size.width;
    final effectiveConstraints = constraints ?? BoxConstraints(
      maxWidth: width > 1200 ? 1200 : width,
    );

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      barrierColor: barrierColor,
      useRootNavigator: useRootNavigator,
      constraints: effectiveConstraints,
      builder: (context) {
        Widget content = child;
        if (heightFactor != null) {
          content = FractionallySizedBox(
            heightFactor: heightFactor,
            child: content,
          );
        }
        return content;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: border,
      ),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );

    if (blurSigma > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: content,
      );
    }

    return content;
  }
}
