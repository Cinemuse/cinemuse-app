import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class CastCarousel extends StatelessWidget {
  final Map<String, dynamic>? credits;
  final String className; // Placeholder to match web prop structure if needed

  const CastCarousel({
    super.key,
    this.credits,
    this.className = '',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cast = (credits?['cast'] as List?)
        ?.take(15)
        .toList() ?? [];

    if (cast.isEmpty) return const SizedBox.shrink();

    return BentoBox(
      title: l10n.detailsCast,
      icon: Icons.people,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none, // Allow scale to "bleed" out
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Room for scale
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cast.map((member) {
              final profilePath = member['profile_path'];
              final name = member['name'] ?? 'Unknown';
              final character = member['character'] ?? '';
              final int? id = member['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _CastCard(
                  profilePath: profilePath,
                  name: name,
                  character: character,
                  onTap: () {
                    if (id != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonDetailsScreen(personId: id),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  final String? profilePath;
  final String name;
  final String character;
  final VoidCallback onTap;

  const _CastCard({
    this.profilePath,
    required this.name,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              AspectRatio(
                aspectRatio: 2 / 3,
                child: HoverScale(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: profilePath != null
                          ? 'https://image.tmdb.org/t/p/w185$profilePath'
                          : '', // Provide an empty string or placeholder URL if profilePath is null
                      height: 120, // This height is not used due to AspectRatio
                      width: 100, // This width is not used due to AspectRatio
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppTheme.secondary),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/cast_placeholder.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                name,
                style: DesktopTypography.bodySecondary.copyWith(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Character
              Text(
                character,
                style: DesktopTypography.captionMeta.copyWith(
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
