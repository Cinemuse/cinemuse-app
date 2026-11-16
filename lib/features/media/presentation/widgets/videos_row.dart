import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/carousels/carousel_vertical_separator.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/video_card.dart';
import 'package:cinemuse_app/features/media/domain/media_details_parts.dart';

sealed class _VideosRowItem {
  const _VideosRowItem();
}

class _LanguageItem extends _VideosRowItem {
  final String label;

  const _LanguageItem(this.label);
}

class _TrailerItem extends _VideosRowItem {
  final MediaVideo trailer;

  const _TrailerItem(this.trailer);
}

/// A title's trailers: those in the app's language first, then the others,
/// each language after a separator when the title has both.
class VideosRow extends StatelessWidget {
  final List<MediaVideo>? videos;

  /// A list going down (a phone) instead of a row scrolling sideways.
  final bool asList;

  const VideosRow({super.key, this.videos, this.asList = false});

  static bool hasTrailers(List<MediaVideo>? videos) {
    if (videos == null) return false;
    return videos.any((v) => v.isYouTubeTrailer);
  }

  @override
  Widget build(BuildContext context) {
    if (videos == null) return const SizedBox.shrink();
    final trailers = videos!.where((v) => v.isYouTubeTrailer).toList();
    if (trailers.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    final appLanguage = Localizations.localeOf(context).languageCode;
    final own = trailers.where((v) => v.language == appLanguage).toList();
    final other = trailers.where((v) => v.language != appLanguage).toList();
    final hasBoth = own.isNotEmpty && other.isNotEmpty;
    final isItalian = appLanguage == 'it';

    final items = <_VideosRowItem>[
      if (hasBoth)
        _LanguageItem(isItalian ? l10n.languageItalian : l10n.languageEnglish),
      ...own.map(_TrailerItem.new),
      if (hasBoth)
        _LanguageItem(isItalian ? l10n.languageEnglish : l10n.languageItalian),
      ...other.map(_TrailerItem.new),
    ];

    void play(MediaVideo trailer) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            queryId: trailer.key,
            type: 'youtube',
            episodeTitle: trailer.name,
            loadingMessage: l10n.playerResolvingYoutube,
          ),
        ),
      );
    }

    if (asList) {
      return BentoBox(
        title: l10n.sectionVisualArchives,
        icon: Icons.movie_filter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, item) in items.indexed)
              switch (item) {
                _LanguageItem(:final label) => Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : 12,
                    bottom: 12,
                  ),
                  child: SeparatorPill(
                    label: label.toUpperCase(),
                    isHighlighted: true,
                    color: AppTheme.accent,
                  ),
                ),
                _TrailerItem(:final trailer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VideoListTile(
                    youtubeKey: trailer.key,
                    name: trailer.name,
                    onTap: () => play(trailer),
                  ),
                ),
              },
          ],
        ),
      );
    }

    return GenericCarouselRow(
      title: l10n.sectionVisualArchives,
      icon: Icons.movie_filter,
      theme: CarouselTheme.bentoBox,
      itemCount: items.length,
      height: 250, // Adjusted to fit 16:9 thumbnail + text + scrollbar
      padding: EdgeInsets
          .zero, // BentoBox already provides padding, avoid double padding
      itemBuilder: (context, index) {
        final item = items[index];

        return switch (item) {
          _LanguageItem(:final label) => CarouselVerticalSeparator(
            label: label.toUpperCase(),
            isHighlighted: true,
            color: AppTheme.accent,
            width: 96, // A language's name is longer than CREW or CAST.
            leadingSpacing: index == 0 ? 0 : 8,
          ),
          _TrailerItem(:final trailer) => Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: VideoCard(
              youtubeKey: trailer.key,
              name: trailer.name,
              onTap: () => play(trailer),
            ),
          ),
        };
      },
    );
  }
}
