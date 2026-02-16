import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';

enum MediaType { movie, tv, person }

class MediaTypeSelector extends StatelessWidget {
  final MediaType selectedType;
  final ValueChanged<MediaType> onTypeChanged;

  const MediaTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TypeButton(
            label: l10n.searchMovies,
            icon: Icons.movie_outlined,
            isSelected: selectedType == MediaType.movie,
            onTap: () => onTypeChanged(MediaType.movie),
          ),
          const SizedBox(width: 4),
          _TypeButton(
            label: l10n.searchSeries,
            icon: Icons.tv_outlined,
            isSelected: selectedType == MediaType.tv,
            onTap: () => onTypeChanged(MediaType.tv),
          ),
          const SizedBox(width: 4),
          _TypeButton(
            label: l10n.searchPersons,
            icon: Icons.person_outline,
            isSelected: selectedType == MediaType.person,
            onTap: () => onTypeChanged(MediaType.person),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
