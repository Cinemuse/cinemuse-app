import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
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
  final List<CastMember>? cast;
  final List<CrewMember>? crew;
  final List<CrewMember>? creators;

  const CastRow({super.key, this.cast, this.crew, this.creators});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final resolvedCast = (cast ?? const []).take(15).toList();
    final resolvedCrew = crew ?? const [];
    final resolvedCreators = creators ?? const [];

    // 1. Extract Creative Team (Directors, Creators, Lead Writers)
    final directors = resolvedCrew.where((c) => c.job == 'Director').toList();
    final writers = resolvedCrew
        .where((c) => c.department == 'Writing')
        .take(3)
        .toList();

    final creativeMembers =
        <({int id, String? profilePath, String name, String role})>[];
    final seenIds = <int>{};

    for (final creator in resolvedCreators) {
      if (seenIds.add(creator.id)) {
        creativeMembers.add((
          id: creator.id,
          profilePath: creator.profilePath,
          name: creator.name.isNotEmpty ? creator.name : 'Unknown',
          role: l10n.detailsCreator,
        ));
      }
    }

    for (final director in directors) {
      if (seenIds.add(director.id)) {
        creativeMembers.add((
          id: director.id,
          profilePath: director.profilePath,
          name: director.name.isNotEmpty ? director.name : 'Unknown',
          role: l10n.detailsDirector,
        ));
      }
    }

    for (final writer in writers) {
      if (seenIds.add(writer.id)) {
        creativeMembers.add((
          id: writer.id,
          profilePath: writer.profilePath,
          name: writer.name.isNotEmpty ? writer.name : 'Unknown',
          role: writer.job ?? l10n.detailsWriter,
        ));
      }
    }

    if (resolvedCast.isEmpty && creativeMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2. Build row items with vertical separators
    final items = <_PeopleRowItem>[];

    if (creativeMembers.isNotEmpty) {
      items.add(
        _DividerItem(label: l10n.detailsSectionCrew, isHighlighted: true),
      );
      for (final member in creativeMembers) {
        items.add(
          _PersonItem(
            id: member.id,
            profilePath: member.profilePath,
            name: member.name,
            subtitle: member.role,
          ),
        );
      }
    }

    if (resolvedCast.isNotEmpty) {
      if (creativeMembers.isNotEmpty) {
        items.add(
          _DividerItem(label: l10n.detailsSectionCast, isHighlighted: true),
        );
      }
      for (final member in resolvedCast) {
        items.add(
          _PersonItem(
            id: member.id,
            profilePath: member.profilePath,
            name: member.name.isNotEmpty ? member.name : 'Unknown',
            subtitle: (member.character ?? '').toString(),
          ),
        );
      }
    }

    final rowTitle = creativeMembers.isNotEmpty
        ? l10n.detailsPeople
        : l10n.detailsCast;

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
                    builder: (context) =>
                        PersonDetailsScreen(personId: person.id!),
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
