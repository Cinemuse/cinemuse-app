import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_action_buttons.dart';
import 'package:cinemuse_app/features/home/presentation/widgets/hero/hero_more_info_pill.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The text block of a hero slide: "Featured" tag, title, overview (wide
/// only), then the "More info" pill (wide) or the Play / info buttons (phone).
class HeroSlideContent extends StatelessWidget {
  final MediaItem item;
  final bool isMobile;
  final bool isWidescreen;
  final bool isHeroFocused;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  const HeroSlideContent({
    super.key,
    required this.item,
    required this.isMobile,
    required this.isWidescreen,
    required this.isHeroFocused,
    required this.onPlay,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final title =
        item.getLocalizedTitle(locale.languageCode) ?? l10n.commonUnknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeaturedTag(isMobile: isMobile),
        SizedBox(height: isMobile ? 8 : 16),
        _HeroTitle(title: title, isMobile: isMobile),
        if (!isMobile) ...[
          const SizedBox(height: 16),
          _HeroOverview(overview: item.overview ?? ''),
        ],
        if (isWidescreen) ...[
          const SizedBox(height: 20),
          HeroMoreInfoPill(isHeroFocused: isHeroFocused),
        ] else ...[
          const SizedBox(height: 16),
          HeroActionButtons(onPlay: onPlay, onDetails: onDetails),
        ],
      ],
    );
  }
}

class _FeaturedTag extends StatelessWidget {
  final bool isMobile;

  const _FeaturedTag({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        l10n.commonFeatured,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
          letterSpacing: isMobile ? 1.5 : 2,
          fontSize: isMobile ? 10 : 12,
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  final String title;
  final bool isMobile;

  const _HeroTitle({required this.title, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final style = isMobile
        ? const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: AppTheme.textWhite,
          )
        : DesktopTypography.heroTitle;

    return Text(
      title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeroOverview extends StatelessWidget {
  final String overview;

  const _HeroOverview({required this.overview});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Text(
        overview,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: AppTheme.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.5,
          letterSpacing: 0.0,
        ),
      ),
    );
  }
}
