import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cards/person_card.dart';

class CastRow extends StatelessWidget {
  final Map<String, dynamic>? credits;
  final String className; // Placeholder to match web prop structure if needed

  const CastRow({super.key, this.credits, this.className = ''});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cast = (credits?['cast'] as List?)?.take(15).toList() ?? [];

    if (cast.isEmpty) return const SizedBox.shrink();

    return GenericCarouselRow(
      title: l10n.detailsCast,
      icon: Icons.people,
      theme: CarouselTheme.bentoBox,
      itemCount: cast.length,
      height: 290, // Standardized BentoBox-style carousels height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemBuilder: (context, index) {
        final member = cast[index];
        final profilePath = member['profile_path'];
        final name = member['name'] ?? 'Unknown';
        final character = member['character'] ?? '';
        final int? id = member['id'];

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: PersonCard(
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
      },
    );
  }
}
