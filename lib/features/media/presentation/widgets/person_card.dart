import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';

class PersonCard extends StatelessWidget {
  final String? profilePath;
  final String name;
  final String character;
  final VoidCallback onTap;

  const PersonCard({
    super.key,
    this.profilePath,
    required this.name,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltipText = character.isNotEmpty ? '$name\n$character' : name;

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 600),
      child: DpadFocusable(
        onTap: onTap,
        scale: 1.05,
        borderRadius: AppTheme.radiusLg,
        showFocusRing: false,
        builder: (context, isFocused, isHovered, child) {
          return SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _PersonPhoto(profilePath: profilePath, isFocused: isFocused),
                const SizedBox(height: 12),
                ..._nameAndRole(
                  theme,
                  name: name,
                  character: character,
                  isLit: isFocused || isHovered,
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }
}

/// [PersonCard] as a line of a list going down, for a phone: a small photo,
/// the name and the role beside it.
class PersonListTile extends StatelessWidget {
  final String? profilePath;
  final String name;
  final String character;
  final VoidCallback onTap;

  const PersonListTile({
    super.key,
    this.profilePath,
    required this.name,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DpadFocusable(
      onTap: onTap,
      borderRadius: AppTheme.radiusLg,
      showFocusRing: false,
      builder: (context, isFocused, isHovered, child) {
        return Row(
          children: [
            SizedBox(
              width: 56,
              child: _PersonPhoto(
                profilePath: profilePath,
                isFocused: isFocused,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _nameAndRole(
                  theme,
                  name: name,
                  character: character,
                  isLit: isFocused || isHovered,
                ),
              ),
            ),
          ],
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

List<Widget> _nameAndRole(
  ThemeData theme, {
  required String name,
  required String character,
  required bool isLit,
}) => [
  Text(
    name,
    style: DesktopTypography.bodySecondary.copyWith(
      color: isLit
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withValues(alpha: 0.9),
      fontWeight: FontWeight.bold,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
  const SizedBox(height: 4),
  Text(
    character,
    style: DesktopTypography.captionMeta.copyWith(
      fontFamily: 'monospace',
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
];

class _PersonPhoto extends StatelessWidget {
  final String? profilePath;
  final bool isFocused;

  const _PersonPhoto({required this.profilePath, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = profilePath;

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppTheme.radiusLg,
            child: CachedNetworkImage(
              imageUrl: path != null
                  ? TmdbImageHelper.profileUrl(context, path)!
                  : '',
              fit: BoxFit.cover,
              memCacheWidth: 270,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) =>
                  Container(color: theme.colorScheme.surfaceContainer),
              errorWidget: (context, url, error) =>
                  Image.asset('assets/cast_placeholder.png', fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: CardFocusBorder(
              isFocused: isFocused,
              borderRadius: AppTheme.radiusLg,
            ),
          ),
        ],
      ),
    );
  }
}
