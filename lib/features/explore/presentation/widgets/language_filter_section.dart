import 'package:cinemuse_app/core/constants/tmdb_constants.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filter_section_label.dart';

/// "Languages": a search box with the matching languages under it, and the
/// picked ones as chips.
class LanguageFilterSection extends ConsumerStatefulWidget {
  const LanguageFilterSection({super.key});

  @override
  ConsumerState<LanguageFilterSection> createState() =>
      _LanguageFilterSectionState();
}

class _LanguageFilterSectionState extends ConsumerState<LanguageFilterSection> {
  final TextEditingController _searchController = TextEditingController();
  bool _isOpen = false;

  void _select(String code) {
    ref.read(exploreFiltersProvider.notifier).addLanguage(code);
    _searchController.clear();
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languages = ref.watch(
      exploreFiltersProvider.select((f) => f.languages),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterSectionLabel(l10n.searchLanguages, subtitle: l10n.searchMatchAny),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onTap: () => setState(() => _isOpen = true),
          onChanged: (v) => setState(() {}),
          style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: l10n.searchLanguagePlaceholder,
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.textWhite),
            ),
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: _LanguageMatches(
              query: _searchController.text,
              onSelect: _select,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in languages)
              Chip(
                label: Text(
                  l10n.languageName(code),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: AppTheme.textWhite.withValues(alpha: 0.1),
                side: BorderSide(
                  color: AppTheme.textWhite.withValues(alpha: 0.1),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => ref
                    .read(exploreFiltersProvider.notifier)
                    .removeLanguage(code),
                labelStyle: const TextStyle(color: AppTheme.textWhite),
              ),
          ],
        ),
      ],
    );
  }
}

/// The languages whose name (in the app's language) contains [query].
class _LanguageMatches extends StatelessWidget {
  final String query;
  final ValueChanged<String> onSelect;

  const _LanguageMatches({required this.query, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lowerQuery = query.toLowerCase();
    final matches = TmdbConstants.languageCodes
        .where((c) => l10n.languageName(c).toLowerCase().contains(lowerQuery))
        .toList();

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          l10n.searchNoLanguagesFound,
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final code = matches[index];
        return ListTile(
          dense: true,
          title: Text(
            l10n.languageName(code),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          onTap: () => onSelect(code),
          hoverColor: AppTheme.textWhite.withValues(alpha: 0.05),
        );
      },
    );
  }
}
