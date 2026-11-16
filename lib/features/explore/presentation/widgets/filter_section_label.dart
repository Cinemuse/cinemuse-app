import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A filter section's title ("Genres"), with an optional muted note
/// ("match all").
class FilterSectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;

  const FilterSectionLabel(this.label, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.textWhite.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ],
    );
  }
}
