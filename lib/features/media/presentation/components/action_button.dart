import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppTheme.textWhite),
      label: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textWhite, 
          fontWeight: FontWeight.bold
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppTheme.accent : AppTheme.textWhite.withOpacity(0.1),
        foregroundColor: AppTheme.textWhite,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : BorderSide(color: AppTheme.textWhite.withOpacity(0.2)),
        ),
      ),
    );
  }
}
