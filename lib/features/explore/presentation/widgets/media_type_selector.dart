import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';

enum MediaType { movie, tv, person }

class MediaTypeSelector extends ConsumerWidget {
  final MediaType selectedType;
  final ValueChanged<MediaType> onTypeChanged;
  final FocusNode? movieFocusNode;
  final FocusNode? tvFocusNode;
  final FocusNode? personFocusNode;

  const MediaTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.movieFocusNode,
    this.tvFocusNode,
    this.personFocusNode,
  });

  KeyEventResult _handleKeyEvent(
    WidgetRef ref,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final focusNavbar = ref.read(topNavbarFocusActionProvider);
      if (focusNavbar != null) {
        focusNavbar();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
            focusNode: movieFocusNode,
            onTap: () => onTypeChanged(MediaType.movie),
            onKeyEvent: (node, event) => _handleKeyEvent(ref, node, event),
          ),
          const SizedBox(width: 4),
          _TypeButton(
            label: l10n.searchSeries,
            icon: Icons.tv_outlined,
            isSelected: selectedType == MediaType.tv,
            focusNode: tvFocusNode,
            onTap: () => onTypeChanged(MediaType.tv),
            onKeyEvent: (node, event) => _handleKeyEvent(ref, node, event),
          ),
          const SizedBox(width: 4),
          _TypeButton(
            label: l10n.searchPersons,
            icon: Icons.person_outline,
            isSelected: selectedType == MediaType.person,
            focusNode: personFocusNode,
            onTap: () => onTypeChanged(MediaType.person),
            onKeyEvent: (node, event) => _handleKeyEvent(ref, node, event),
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
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onTap: onTap,
      scale: 1.05,
      borderRadius: BorderRadius.circular(10),
      builder: (context, isFocused, isHovered, _) {
        final isHighlighted = isFocused || isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : (isHighlighted
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.black
                    : (isHighlighted ? Colors.white : AppTheme.textMuted),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.black
                      : (isHighlighted ? Colors.white : AppTheme.textMuted),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
