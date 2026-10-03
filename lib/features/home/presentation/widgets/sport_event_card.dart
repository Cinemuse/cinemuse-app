import 'package:cinemuse_app/features/home/application/sport_schedule_scraper.dart';
import 'package:cinemuse_app/shared/widgets/menu/app_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:cinemuse_app/shared/widgets/card_focus_border.dart';
import 'package:cinemuse_app/core/application/display_mode_provider.dart';
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
    // Navigate to Live TV tab
    ref.read(navIndexProvider.notifier).state = 2;
    // Reset filters and select ALL tab
    ref.read(liveTvTabProvider.notifier).state = LiveTvTab.all;
    ref.read(channelFilterProvider.notifier).state = const ChannelFilter();
    // Pre-fill search with the selected channel
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String imageAsset;
    final key = widget.event.sportTranslationKey;
    if (key == 'sport_motorcycling') {
      imageAsset = 'assets/sports/sport_motogp.jpg';
    } else if (key == 'sport_volleyball') {
      imageAsset = 'assets/sports/sport_volleyball.png';
    } else {
      imageAsset = 'assets/sports/$key.jpg';
    }

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
                      // Backdrop Image
                      AspectRatio(
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
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  imageAsset,
                                  fit: BoxFit.cover,
                                  color: Colors.black.withValues(alpha: 0.3),
                                  colorBlendMode: BlendMode.darken,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholder(context),
                                ),
                              ),

                              // Time Badge
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.glass,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: theme.colorScheme.primary,
                                        size: 10,
                                      ),
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
                                ),
                              ),

                              // Channels Overlay
                              if (widget.event.channels.isNotEmpty)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: widget.event.channels
                                        .map(
                                          (channel) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface
                                                  .withValues(alpha: 0.8),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Text(
                                              channel,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .copyWith(
                                                    color: AppTheme.textWhite,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),

                              // Border Overlay
                              const CardFocusBorder(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title (Sport Name & Description)
                      Builder(
                        builder: (context) {
                          final isHighlighted =
                              DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
                          final theme = Theme.of(context);
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
                      ),
                    ],
                  ),

              // Context Menu Button (More Options)
              if (widget.event.channels.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Builder(
                    builder: (context) {
                      final isHighlighted =
                          DpadFocusScope.maybeOf(context)?.isHighlighted ?? false;
                      final isBigPicture = ref.watch(isBigPictureProvider);
                      if (isBigPicture) return const SizedBox.shrink();
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
                  ),
                ),
            ],
          ),
        ),
      );
  }

  String _getLocalizedSportName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return widget.event.sportName;

    switch (widget.event.sportTranslationKey) {
      case 'sport_football':
        return l10n.sportFootball;
      case 'sport_basketball':
        return l10n.sportBasketball;
      case 'sport_motorcycling':
        return l10n.sportMotorcycling;
      case 'sport_volleyball':
        return l10n.sportVolleyball;
      case 'sport_athletics':
        return l10n.sportAthletics;
      case 'sport_tennis':
        return l10n.sportTennis;
      case 'sport_cycling':
        return l10n.sportCycling;
      case 'sport_rugby':
        return l10n.sportRugby;
      case 'sport_f1':
        return l10n.sportF1;
      default:
        return widget.event.sportName.isNotEmpty
            ? widget.event.sportName
            : l10n.sportGeneric;
    }
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
