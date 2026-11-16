import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/domain/agenda_event.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _posterFallback = Icon(LucideIcons.film, size: 20, color: Colors.white24);

/// One upcoming movie or episode in the agenda.
class AgendaEventRow extends StatelessWidget {
  final AgendaEvent event;

  const AgendaEventRow({super.key, required this.event});

  /// "S1 E2 • Name". The name is left out when it only repeats the number
  /// ("Episode 2", "Episodio 2", "2"), in any language (REV-109).
  String _episodeLabel(AppLocalizations l10n) {
    final season = event.seasonNumber!;
    final episode = event.episodeNumber!;
    final name = event.episodeName?.trim() ?? '';
    final onlyNumber = RegExp('^(\\p{L}+\\s*)?$episode\$', unicode: true);
    return name.isEmpty || onlyNumber.hasMatch(name)
        ? l10n.seasonEpisodeShort(season, episode)
        : l10n.detailsEpisodeWithSeason(season, episode, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DpadFocusable(
      // Rows sit edge to edge: the ring goes on the row's own edge.
      isFocusRingInside: true,
      borderRadius: BorderRadius.zero,
      builder: (context, isFocused, isHovered, child) => ColoredBox(
        color: isHovered ? Theme.of(context).hoverColor : Colors.transparent,
        child: child,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaDetailsScreen(
            mediaId: event.tmdbId.toString(),
            mediaType: event.type.name,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 72,
                color: Colors.white10,
                child: event.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: TmdbImageHelper.posterUrl(
                          context,
                          event.posterPath,
                        )!,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (48 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorWidget: (_, _, _) => _posterFallback,
                      )
                    : _posterFallback,
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
                    style: DesktopTypography.bodySecondary.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.type == MediaKind.tv &&
                      event.seasonNumber != null &&
                      event.episodeNumber != null)
                    Text(
                      _episodeLabel(l10n),
                      style: DesktopTypography.captionMeta.copyWith(
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: event.type == MediaKind.tv
                                ? AppTheme.info.withValues(alpha: 0.3)
                                : AppTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          (event.type == MediaKind.tv
                                  ? l10n.agendaSeries
                                  : l10n.agendaMovie)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: event.type == MediaKind.tv
                                ? AppTheme.info
                                : AppTheme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.isTbd
                            ? (event.customReleaseDate ?? l10n.agendaTbdLabel)
                            : DateFormat.yMMMd(
                                Localizations.localeOf(context).languageCode,
                              ).format(event.releaseDate),
                        style: DesktopTypography.captionMeta.copyWith(
                          fontSize: 12,
                        ),
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
