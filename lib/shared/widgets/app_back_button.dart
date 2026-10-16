import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color iconColor;
  final double padding;

  const AppBackButton({
    super.key,
    required this.onTap,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.padding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      scale: 1.05,
      tooltip: AppLocalizations.of(context)!.commonGoBack,
      onTap: onTap,
      borderRadius: AppTheme.radiusFull,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(Icons.arrow_back, color: iconColor, size: 20),
      ),
    );
  }
}
