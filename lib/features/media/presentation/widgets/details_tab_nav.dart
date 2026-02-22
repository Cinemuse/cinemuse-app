import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

enum DetailsTab {
  episodes,
  cast,
  reviews,
  videos,
  finances,
  links,
}

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
    final l10n = AppLocalizations.of(context)!;

    // 1:1 Order from cinemuse-web
    final tabs = [
      if (isTV && numberOfSeasons > 0) 
        _TabItem(DetailsTab.episodes, l10n.detailsEpisodes),
      _TabItem(DetailsTab.cast, l10n.detailsCast),
      _TabItem(DetailsTab.reviews, l10n.detailsReviews),
      _TabItem(DetailsTab.videos, l10n.detailsVideos),
      if (hasFinances) 
        _TabItem(DetailsTab.finances, l10n.detailsFinances),
      _TabItem(DetailsTab.links, l10n.detailsLinks),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: tabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(_TabItem item) {
    final isActive = activeTab == item.tab;

    return GestureDetector(
      onTap: () => onTabChanged(item.tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          item.label.toUpperCase(),
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final DetailsTab tab;
  final String label;
  _TabItem(this.tab, this.label);
}
