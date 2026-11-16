import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// The user's own review, as typed in Markdown: bold, italics, headings, lists
/// and quotes show formatted. Links are plain text and images never load.
/// Outside reviews stay plain text: their stray asterisks would turn into odd
/// formatting.
class OwnReviewText extends StatelessWidget {
  final String text;

  const OwnReviewText(this.text, {super.key});

  static const _body = TextStyle(
    color: AppTheme.textWhite,
    fontSize: 14,
    height: 1.4,
  );

  static const _heading = TextStyle(
    color: AppTheme.textWhite,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      // A picture would load from whatever address was typed; its description
      // stays. No link handler either, so nothing opens.
      sizedImageBuilder: (config) => Text(config.alt ?? '', style: _body),
      styleSheet: MarkdownStyleSheet(
        p: _body,
        a: _body,
        strong: const TextStyle(fontWeight: FontWeight.bold),
        em: const TextStyle(fontStyle: FontStyle.italic),
        listBullet: _body.copyWith(color: AppTheme.accent),
        h1: _heading.copyWith(fontSize: 18),
        h2: _heading.copyWith(fontSize: 16),
        h3: _heading.copyWith(fontSize: 15),
        h4: _heading.copyWith(fontSize: 14),
        h5: _heading.copyWith(fontSize: 14),
        h6: _heading.copyWith(fontSize: 14),
        blockquote: _body.copyWith(color: AppTheme.textSecondary),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.textWhite.withValues(alpha: 0.05),
          borderRadius: AppTheme.radiusSm,
        ),
      ),
    );
  }
}
