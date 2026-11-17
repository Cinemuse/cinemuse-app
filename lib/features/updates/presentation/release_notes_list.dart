import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/updates/domain/release_notes.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// "What's new", then each new version's number and its notes in the
/// app's language, newest first.
class ReleaseNotesList extends StatelessWidget {
  final List<ReleaseNotes> notes;

  const ReleaseNotesList({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.updateWhatsNew,
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        for (final version in notes) ...[
          const SizedBox(height: 16),
          Text(
            version.version,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: version.inLanguage(language),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              h1: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              h2: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              // "New" and "Fixed" under each version (CONTRIBUTING.md)
              h3: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
              h3Padding: const EdgeInsets.only(top: 4),
              listBullet: const TextStyle(color: AppTheme.accent),
            ),
          ),
        ],
      ],
    );
  }
}
