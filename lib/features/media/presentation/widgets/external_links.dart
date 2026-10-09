import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

const Color _kImdbBrandColor = Color(0xFFF5C518);
const Color _kTmdbBrandColor = Color(0xFF01B4E4);

class ExternalLinks extends StatelessWidget {
  final ExternalIds? ids;
  final String? homepage;
  final String type;
  final int tmdbId;

  const ExternalLinks({
    super.key,
    this.ids,
    this.homepage,
    required this.type,
    required this.tmdbId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedIds = ids;

    // Row 1: Themed Brand Buttons (IMDb, TMDB)
    final brandButtons = <Widget>[];

    final imdbId = resolvedIds?.imdbId;
    if (imdbId != null && imdbId.trim().isNotEmpty) {
      final category = type == 'person' ? 'name' : 'title';
      brandButtons.add(
        _ThemedBrandButton(
          label: 'IMDb',
          url: 'https://www.imdb.com/$category/$imdbId',
          brandColor: _kImdbBrandColor,
        ),
      );
    }

    if (tmdbId > 0) {
      final tmdbType = type == 'series' ? 'tv' : type;
      brandButtons.add(
        _ThemedBrandButton(
          label: 'TMDB',
          url: 'https://www.themoviedb.org/$tmdbType/$tmdbId',
          brandColor: _kTmdbBrandColor,
        ),
      );
    }

    // Row 2: Smaller Square Icon Buttons (social media + official website + wikidata)
    final squareButtons = <Widget>[];

    if (homepage != null && homepage!.trim().isNotEmpty) {
      squareButtons.add(
        _SquareIconButton(
          icon: Icons.language,
          url: homepage!,
          tooltip: l10n.detailsOfficialWebsite,
        ),
      );
    }

    final instagramId = resolvedIds?.instagramId;
    if (instagramId != null && instagramId.trim().isNotEmpty) {
      squareButtons.add(
        _SquareIconButton(
          icon: LucideIcons.instagram,
          url: 'https://instagram.com/$instagramId',
          tooltip: 'Instagram',
        ),
      );
    }

    final facebookId = resolvedIds?.facebookId;
    if (facebookId != null && facebookId.trim().isNotEmpty) {
      squareButtons.add(
        _SquareIconButton(
          icon: LucideIcons.facebook,
          url: 'https://facebook.com/$facebookId',
          tooltip: 'Facebook',
        ),
      );
    }

    final twitterId = resolvedIds?.twitterId;
    if (twitterId != null && twitterId.trim().isNotEmpty) {
      squareButtons.add(
        _SquareIconButton(
          icon: LucideIcons.twitter,
          url: 'https://twitter.com/$twitterId',
          tooltip: 'Twitter',
        ),
      );
    }

    final wikidataId = resolvedIds?.wikidataId;
    if (wikidataId != null && wikidataId.trim().isNotEmpty) {
      squareButtons.add(
        _SquareIconButton(
          icon: LucideIcons.database,
          url: 'https://www.wikidata.org/wiki/$wikidataId',
          tooltip: 'Wikidata',
        ),
      );
    }

    if (brandButtons.isEmpty && squareButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return BentoBox(
      title: l10n.detailsExternalLinks.toUpperCase(),
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (brandButtons.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: brandButtons,
            ),
          if (brandButtons.isNotEmpty && squareButtons.isNotEmpty)
            const SizedBox(height: 12),
          if (squareButtons.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: squareButtons,
            ),
        ],
      ),
    );
  }
}

class _ThemedBrandButton extends StatelessWidget {
  final String label;
  final String url;
  final Color brandColor;

  const _ThemedBrandButton({
    required this.label,
    required this.url,
    required this.brandColor,
  });

  Future<void> _handleTap() async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      scale: 1.05,
      showFocusRing: true,
      focusRingColor: brandColor,
      borderRadius: AppTheme.radius12,
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.6),
          borderRadius: AppTheme.radius12,
          border: Border.all(
            color: brandColor.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: brandColor.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: brandColor,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final String url;
  final String tooltip;

  const _SquareIconButton({
    required this.icon,
    required this.url,
    required this.tooltip,
  });

  Future<void> _handleTap() async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverScale(
        scale: 1.1,
        showFocusRing: true,
        focusRingColor: AppTheme.accent,
        borderRadius: AppTheme.radius12,
        onTap: _handleTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.5),
            borderRadius: AppTheme.radius12,
            border: Border.all(
              color: AppTheme.borderSubtle,
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.textWhite.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
