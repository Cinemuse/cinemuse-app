import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:flutter/material.dart';

import 'genre_filter_section.dart';
import 'language_filter_section.dart';
import 'range_filters_section.dart';
import 'sort_filter_section.dart';
import 'watch_provider_filter_section.dart';

/// The Explore filters sheet: three columns on a wide sheet, one under the
/// other on a narrow one.
class ExploreFilterPanel extends StatelessWidget {
  const ExploreFilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= Breakpoints.medium;
          final columnWidth = isWide
              ? (constraints.maxWidth - 64) / 3
              : constraints.maxWidth;
          return Wrap(
            spacing: 32,
            runSpacing: 32,
            children: [
              SizedBox(
                width: columnWidth,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SortFilterSection(),
                    SizedBox(height: 32),
                    LanguageFilterSection(),
                  ],
                ),
              ),
              SizedBox(
                width: columnWidth,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GenreFilterSection(),
                    SizedBox(height: 32),
                    WatchProviderFilterSection(),
                  ],
                ),
              ),
              SizedBox(width: columnWidth, child: const RangeFiltersSection()),
            ],
          );
        },
      ),
    );
  }
}
