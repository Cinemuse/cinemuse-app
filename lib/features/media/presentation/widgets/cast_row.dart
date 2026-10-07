import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/person_card.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_vertical_separator.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:flutter/material.dart';

sealed class _PeopleRowItem {
  const _PeopleRowItem();
}

class _DividerItem extends _PeopleRowItem {
  final String label;
  final bool isHighlighted;

  const _DividerItem({required this.label, this.isHighlighted = false});
}

class _PersonItem extends _PeopleRowItem {
  final int? id;
  final String? profilePath;
  final String name;
  final String subtitle;

  const _PersonItem({
    this.id,
    this.profilePath,
    required this.name,
    required this.subtitle,
  });
}

class CastRow extends StatelessWidget {
  final Map<String, dynamic>? credits;
  final Map<String, dynamic>? details;
  final String className;

  const CastRow({
    super.key,
    this.credits,
    this.details,
    this.className = '',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedCredits = credits ?? (details?['credits'] as Map<String, dynamic>?);
    final crew = (resolvedCredits?['crew'] as List?) ?? [];
    final cast = (resolvedCredits?['cast'] as List?)?.take(15).toList() ?? [];

    // 1. Extract Creative Team (Directors, Creators, Lead Writers)
    final directors = crew.where((c) => c is Map && c['job'] == 'Director').toList();
    final creators = (details?['created_by'] as List?) ?? [];
    final writers = crew
        .where((c) => c is Map && c['department'] == 'Writing')
        .take(3)
        .toList();

    final creativeMembers = <Map<String, dynamic>>[];
    final seenIds = <int>{};

    for (final creator in creators) {
      if (creator is Map) {
        final id = creator['id'] as int?;
        if (id != null && seenIds.add(id)) {
          creativeMembers.add({
            ...Map<String, dynamic>.from(creator),
            'role': l10n.detailsCreator,
          });
        }
      }
    }

    for (final director in directors) {
      if (director is Map) {
        final id = director['id'] as int?;
        if (id != null && seenIds.add(id)) {
          creativeMembers.add({
            ...Map<String, dynamic>.from(director),
            'role': l10n.detailsDirector,
          });
        }
      }
    }

    for (final writer in writers) {
      if (writer is Map) {
        final id = writer['id'] as int?;
        if (id != null && seenIds.add(id)) {
          creativeMembers.add({
            ...Map<String, dynamic>.from(writer),
            'role': writer['job'] ?? l10n.detailsWriter,
          });
        }
      }
    }

    if (cast.isEmpty && creativeMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2. Build row items with vertical separators
    final items = <_PeopleRowItem>[];

    if (creativeMembers.isNotEmpty) {
      items.add(_DividerItem(label: l10n.detailsSectionCrew, isHighlighted: true));
      for (final member in creativeMembers) {
        items.add(
          _PersonItem(
            id: member['id'] as int?,
            profilePath: member['profile_path'] as String?,
            name: (member['name'] ?? 'Unknown').toString(),
            subtitle: (member['role'] ?? '').toString(),
          ),
        );
      }
    }

    if (cast.isNotEmpty) {
      if (creativeMembers.isNotEmpty) {
        items.add(_DividerItem(label: l10n.detailsSectionCast, isHighlighted: true));
      }
      for (final member in cast) {
        if (member is Map) {
          items.add(
            _PersonItem(
              id: member['id'] as int?,
              profilePath: member['profile_path'] as String?,
              name: (member['name'] ?? 'Unknown').toString(),
              subtitle: (member['character'] ?? '').toString(),
            ),
          );
        }
      }
    }

    final rowTitle = creativeMembers.isNotEmpty ? l10n.detailsPeople : l10n.detailsCast;

    return GenericCarouselRow(
      title: rowTitle,
      icon: Icons.people,
      theme: CarouselTheme.bentoBox,
      itemCount: items.length,
      height: 290,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is _DividerItem) {
          return CarouselVerticalSeparator(
            label: item.label,
            isHighlighted: item.isHighlighted,
            color: item.isHighlighted ? AppTheme.accent : null,
            leadingSpacing: index == 0 ? 0 : 8,
            trailingSpacing: 16,
          );
        }

        final person = item as _PersonItem;
        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: PersonCard(
            profilePath: person.profilePath,
            name: person.name,
            character: person.subtitle,
            onTap: () {
              if (person.id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonDetailsScreen(personId: person.id!),
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
