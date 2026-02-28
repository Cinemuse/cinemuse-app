import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/profile/application/agenda_providers.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class AgendaWidget extends ConsumerWidget {
  const AgendaWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(agendaProvider);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 20, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      l10n.agendaTitle,
                      style: DesktopTypography.bentoHeader,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.agendaSubtitle,
                  style: DesktopTypography.captionMeta,
                ),
              ],
            ),
          ),

          // Content
          agendaAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      l10n.agendaNoEvents,
                      style: DesktopTypography.bodySecondary.copyWith(color: AppTheme.textMuted),
                    ),
                  ),
                );
              }

              return Column(
                children: groups.entries.map((entry) {
                  return _GroupSection(group: entry.key, events: entry.value);
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n.commonError,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final AgendaGroup group;
  final List<AgendaEvent> events;

  const _GroupSection({required this.group, required this.events});

  String _getGroupTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (group) {
      case AgendaGroup.recentlyReleased: return l10n.agendaRecentlyReleased;
      case AgendaGroup.today: return l10n.agendaToday;
      case AgendaGroup.tomorrow: return l10n.agendaTomorrow;
      case AgendaGroup.thisWeek: return l10n.agendaThisWeek;
      case AgendaGroup.nextWeek: return l10n.agendaNextWeek;
      case AgendaGroup.later: return l10n.agendaLater;
      case AgendaGroup.tbd: return l10n.agendaTbd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: Colors.white.withOpacity(0.05),
          child: Text(
            _getGroupTitle(context).toUpperCase(),
            style: DesktopTypography.captionMeta.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          itemBuilder: (context, index) => _AgendaEventItem(event: events[index]),
        ),
      ],
    );
  }
}

class _AgendaEventItem extends StatelessWidget {
  final AgendaEvent event;

  const _AgendaEventItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat.MMMd().format(event.releaseDate);

    return InkWell(
      onTap: () {
        // TODO: Navigate to details
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Poster Small
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 72,
                color: Colors.white10,
                child: event.posterPath != null
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w200${event.posterPath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(LucideIcons.film, size: 20, color: Colors.white24),
                      )
                    : const Icon(LucideIcons.film, size: 20, color: Colors.white24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: DesktopTypography.bodySecondary.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.type == MediaKind.tv && event.seasonNumber != null)
                    Builder(
                      builder: (context) {
                        final sLabel = l10n.detailsSeasonNumber(event.seasonNumber!).split(' ').first[0]; // 'S'
                        final eLabel = l10n.detailsEpisodeNumber(event.episodeNumber!).split(' ').first; // 'EP' or 'E'
                        
                        // Check if episodeName is redundant
                        final epName = event.episodeName ?? "";
                        final isRedundant = epName.toLowerCase().contains('episode ${event.episodeNumber}') || 
                                           epName.toLowerCase() == 'episode ${event.episodeNumber}' ||
                                           epName.trim() == event.episodeNumber.toString();
                        
                        return Text(
                          '$sLabel${event.seasonNumber} $eLabel${event.episodeNumber}${!isRedundant && epName.isNotEmpty ? ' • $epName' : ''}',
                          style: DesktopTypography.captionMeta.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: event.type == MediaKind.tv 
                              ? Colors.blue.withOpacity(0.3) 
                              : AppTheme.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          (event.type == MediaKind.tv ? l10n.agendaSeries : l10n.agendaMovie).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: event.type == MediaKind.tv ? Colors.blue[300] : AppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.isTbd 
                          ? (event.customReleaseDate ?? l10n.agendaTbdLabel)
                          : DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(event.releaseDate),
                        style: DesktopTypography.captionMeta.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
