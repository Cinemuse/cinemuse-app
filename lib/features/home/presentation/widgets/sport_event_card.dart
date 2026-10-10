import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SportEventCard extends ConsumerStatefulWidget {
  final SportTvEvent event;

  const SportEventCard({super.key, required this.event});

  @override
  ConsumerState<SportEventCard> createState() => _SportEventCardState();
}

class _SportEventCardState extends ConsumerState<SportEventCard> {
  final GlobalKey _menuKey = GlobalKey();

  void _navigateToLiveTvSearch(String channelName) {
    ref.read(navIndexProvider.notifier).state = NavTab.liveTv;
    ref.read(liveTvTabProvider.notifier).state = LiveTvTab.all;
    ref.read(channelFilterProvider.notifier).state = const ChannelFilter();
    ref.read(channelSearchQueryProvider.notifier).state = channelName;
  }

  void _handleTap() {
    if (widget.event.channels.isEmpty) return;
    if (widget.event.channels.length == 1) {
      _navigateToLiveTvSearch(widget.event.channels.first);
    } else {
      _showContextActions(context);
    }
  }

  void _showContextActions(
    BuildContext context, {
    BuildContext? anchorContext,
  }) {
    if (widget.event.channels.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final localizedSport = _getLocalizedSportName(context);

    final options = widget.event.channels
        .map(
          (channel) => AppMenuOption(
            icon: Icons.tv,
            label: l10n?.sportWatchOnChannel(channel) ?? 'Watch on $channel',
            onTap: () => _navigateToLiveTvSearch(channel),
          ),
        )
        .toList();

    AppMenu.show(
      context: context,
      options: options,
      title: localizedSport.isNotEmpty
          ? localizedSport
          : (l10n?.sportChannelsTitle ?? 'Channels'),
      anchorContext: anchorContext ?? _menuKey.currentContext,
    );
  }

  String _getDateTimeString(BuildContext context) {
    final eventTime = widget.event.dateTime;
    if (eventTime == null) return '--:--';

    final l10n = AppLocalizations.of(context);
    final timeStr = DateFormat('HH:mm').format(eventTime);
    if (l10n == null) return timeStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final normalised = DateTime(eventTime.year, eventTime.month, eventTime.day);

    String dayStr;
    if (normalised == today) {
      dayStr = l10n.agendaToday;
    } else if (normalised == tomorrow) {
      dayStr = l10n.agendaTomorrow;
    } else {
      dayStr = DateFormat(
        'E d MMM',
        Localizations.localeOf(context).toString(),
      ).format(eventTime);
    }

    return '$dayStr • $timeStr';
  }

  String _getLocalizedSportName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return widget.event.sportName;

    final sportLabels = <String, String>{
      'sport_football': l10n.sportFootball,
      'sport_basketball': l10n.sportBasketball,
      'sport_motorcycling': l10n.sportMotorcycling,
      'sport_volleyball': l10n.sportVolleyball,
      'sport_athletics': l10n.sportAthletics,
      'sport_tennis': l10n.sportTennis,
      'sport_cycling': l10n.sportCycling,
      'sport_rugby': l10n.sportRugby,
      'sport_f1': l10n.sportF1,
    };

    return sportLabels[widget.event.sportTranslationKey] ??
        (widget.event.sportName.isNotEmpty
            ? widget.event.sportName
            : l10n.sportGeneric);
  }

  static const _sportAssetOverrides = <String, String>{
    'sport_motorcycling': 'assets/sports/sport_motogp.jpg',
    'sport_volleyball': 'assets/sports/sport_volleyball.png',
  };

  String _getSportAsset() {
    final key = widget.event.sportTranslationKey;
    return _sportAssetOverrides[key] ?? 'assets/sports/$key.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DpadFocusable(
      onTap: _handleTap,
      onLongPress: () => _showContextActions(context),
      onSecondaryTap: () => _showContextActions(context),
      scale: 1.02,
      showFocusRing: false,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 280,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackdrop(theme),
                const SizedBox(height: 8),
                _buildTitle(theme),
              ],
            ),
            if (widget.event.channels.isNotEmpty)
              Positioned(top: 8, right: 8, child: _buildContextMenuButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop(ThemeData theme) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          boxShadow: AppTheme.shadowCard,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _getSportAsset(),
                fit: BoxFit.cover,
                color: AppTheme.primary.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(context),
              ),
            ),
            Positioned(top: 8, left: 8, child: _buildTimeBadge(theme)),
            if (widget.event.channels.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _buildChannelsOverlay(theme),
              ),
            const CardFocusBorder(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, color: theme.colorScheme.primary, size: 10),
          const SizedBox(width: 4),
          Text(
            _getDateTimeString(context),
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsOverlay(ThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: widget.event.channels
          .map(
            (channel) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                channel,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.textWhite,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Builder(
      builder: (context) {
        final isHighlighted =
            DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
        final localizedSport = _getLocalizedSportName(context);

        return Text(
          localizedSport.isNotEmpty
              ? '$localizedSport${widget.event.description.isNotEmpty ? ' - ${widget.event.description}' : ''}'
              : widget.event.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: isHighlighted
                ? theme.colorScheme.primary
                : AppTheme.textWhite,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        );
      },
    );
  }

  Widget _buildContextMenuButton() {
    return Builder(
      builder: (context) {
        final isHighlighted =
            DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
        final isMobile = MediaQuery.of(context).size.width < 600;

        return AnimatedOpacity(
          opacity: (isHighlighted || isMobile) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              canRequestFocus: false,
              excludeFromSemantics: true,
              onTap: () => _showContextActions(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                key: _menuKey,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.glass,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: AppTheme.textWhite,
                  size: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_soccer,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
              size: 40,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _getLocalizedSportName(context),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
