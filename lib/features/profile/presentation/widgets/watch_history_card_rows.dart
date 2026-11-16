import 'package:cinemuse_app/features/profile/presentation/widgets/watch_history_card.dart';
import 'package:flutter/material.dart';

/// A header, then its cards.
class WatchHistoryCardSection {
  final Widget header;
  final int cardCount;
  final Widget Function(int index) cardBuilder;

  const WatchHistoryCardSection({
    required this.header,
    required this.cardCount,
    required this.cardBuilder,
  });
}

/// The timeline's and the ratings' sections: each header, then its cards in
/// rows. A sliver; it builds only the rows on screen.
class WatchHistoryCardRows extends StatelessWidget {
  final List<WatchHistoryCardSection> sections;

  const WatchHistoryCardRows({super.key, required this.sections});

  static const _headerHeight = 52.0;
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = watchHistoryColumnCount(width);
        final cardWidth =
            (width - (columns - 1) * watchHistoryCardSpacing) / columns;
        final cardHeight = cardWidth / watchHistoryCardAspectRatio;
        final rows = _rows(columns);

        return SliverVariedExtentList.builder(
          itemCount: rows.length,
          itemExtentBuilder: (index, _) =>
              rows[index] is _CardsRow ? cardHeight + _rowGap : _headerHeight,
          itemBuilder: (context, index) => switch (rows[index]) {
            final WatchHistoryCardSection section => Align(
              alignment: Alignment.centerLeft,
              child: section.header,
            ),
            final _CardsRow row => Padding(
              padding: const EdgeInsets.only(bottom: _rowGap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = row.start; i < row.end; i++) ...[
                    if (i > row.start)
                      const SizedBox(width: watchHistoryCardSpacing),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: row.section.cardBuilder(i),
                    ),
                  ],
                ],
              ),
            ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }

  /// Each section, then its cards in rows of [columns].
  List<Object> _rows(int columns) => [
    for (final section in sections) ...[
      section,
      for (int i = 0; i < section.cardCount; i += columns)
        _CardsRow(section, i, (i + columns).clamp(0, section.cardCount)),
    ],
  ];
}

class _CardsRow {
  final WatchHistoryCardSection section;
  final int start;
  final int end;

  const _CardsRow(this.section, this.start, this.end);
}
