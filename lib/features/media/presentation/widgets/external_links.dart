import 'package:flutter/material.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/app_browser.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ExternalLinks extends StatelessWidget {
  final Map<String, dynamic>? externalIds;
  final String? homepage;
  final String title;
  final String type;
  final int tmdbId;

  const ExternalLinks({
    super.key, 
    this.externalIds, 
    this.homepage,
    required this.title,
    required this.type,
    required this.tmdbId,
  });

  @override
  Widget build(BuildContext context) {
    if (externalIds == null && homepage == null) return const SizedBox.shrink();

    return BentoBox(
      title: 'EXTERNAL LINKS',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (externalIds != null) ...[
            Row(
              children: [
                if (externalIds!['instagram_id'] != null)
                  _SocialLink(
                    icon: FontAwesomeIcons.instagram,
                    url: 'https://instagram.com/${externalIds!['instagram_id']}',
                    label: 'Instagram',
                  ),
                if (externalIds!['facebook_id'] != null)
                  _SocialLink(
                    icon: FontAwesomeIcons.facebook,
                    url: 'https://facebook.com/${externalIds!['facebook_id']}',
                    label: 'Facebook',
                  ),
                if (homepage != null)
                  _SocialLink(
                    icon: Icons.language,
                    url: homepage!,
                    label: 'Official Website',
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (externalIds!['imdb_id'] != null)
                _DatabaseLink(
                  label: 'IMDb',
                  url: 'https://www.imdb.com/title/${externalIds!['imdb_id']}',
                ),
              if (externalIds!['wikidata_id'] != null)
                _DatabaseLink(
                  label: 'Wikidata',
                  url: 'https://www.wikidata.org/wiki/${externalIds!['wikidata_id']}',
                ),
              _DatabaseLink(
                label: 'TMDB',
                url: 'https://www.themoviedb.org/',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialLink extends StatelessWidget {
  final IconData icon;
  final String url;
  final String label;

  const _SocialLink({required this.icon, required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => AppBrowser.show(context, url: url, title: label),
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: HoverScale(
            scale: 1.2,
            child: Icon(icon, color: AppTheme.textWhite.withOpacity(0.6), size: 20),
          ),
        ),
      ),
    );
  }
}

class _DatabaseLink extends StatelessWidget {
  final String label;
  final String url;

  const _DatabaseLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => AppBrowser.show(context, url: url, title: label),
        child: HoverScale(
          scale: 1.1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.textWhite.withOpacity(0.05)),
            ),
            child: Text(
              label,
              style: GoogleFonts.firaCode(
                color: AppTheme.textWhite.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
