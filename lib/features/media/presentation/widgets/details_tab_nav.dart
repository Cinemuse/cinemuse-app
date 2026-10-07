import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

enum DetailsTab { episodes, cast, reviews, media, finances, links, more }

class DetailsTabNav extends StatelessWidget {
  final DetailsTab activeTab;
  final ValueChanged<DetailsTab> onTabChanged;
  final bool isTV;
  final int numberOfSeasons;
  final bool hasFinances;

  const DetailsTabNav({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.isTV,
    required this.numberOfSeasons,
    required this.hasFinances,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 1:1 Order from cinemuse-web
    final tabs = [
      if (isTV && numberOfSeasons > 0)
        _TabItem(DetailsTab.episodes, l10n.detailsEpisodes),
      _TabItem(DetailsTab.cast, l10n.detailsCast),
      _TabItem(DetailsTab.media, l10n.detailsMedia),
      if (hasFinances) _TabItem(DetailsTab.finances, l10n.detailsFinances),
      _TabItem(DetailsTab.links, l10n.detailsLinks),
      _TabItem(DetailsTab.more, l10n.detailsMore),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(children: tabs.map((tab) => _buildTab(context, tab)).toList()),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, _TabItem item) {
    final theme = Theme.of(context);
    final isActive = activeTab == item.tab;

    return DpadFocusable(
      onTap: () => onTabChanged(item.tab),
      showFocusRing: false,
      scale: 1.0,
      child: const SizedBox.shrink(),
      builder: (context, isFocused, isHovered, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isFocused
                ? theme.focusColor
                : (isHovered ? theme.hoverColor : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? theme.colorScheme.primary
                    : (isFocused ? theme.colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent),
                width: 2,
              ),
            ),
          ),
          child: Text(
            item.label.toUpperCase(),
            style: TextStyle(
              color: (isActive || isFocused)
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final DetailsTab tab;
  final String label;
  _TabItem(this.tab, this.label);
}
