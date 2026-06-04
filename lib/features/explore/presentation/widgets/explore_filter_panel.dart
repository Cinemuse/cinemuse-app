import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../../../core/constants/tmdb_constants.dart';
import 'explore_filters.dart';
import 'filter_range_slider.dart';

import 'package:cinemuse_app/features/explore/application/explore_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/premium_hover_text.dart';
import '../../../../shared/widgets/hover_scale.dart';

class ExploreFilterPanel extends ConsumerStatefulWidget {
  const ExploreFilterPanel({super.key});

  @override
  ConsumerState<ExploreFilterPanel> createState() => _ExploreFilterPanelState();
}

class _ExploreFilterPanelState extends ConsumerState<ExploreFilterPanel> {
  final TextEditingController _langSearchController = TextEditingController();
  bool _isLangOpen = false;

  void _updateFilters(ExploreFilters newFilters) {
    ref.read(exploreFiltersProvider.notifier).state = newFilters;
    ref.read(exploreResultsProvider.notifier).reset();
  }

  void _toggleGenre(int genreId) {
    final filters = ref.read(exploreFiltersProvider);
    final newGenres = List<int>.from(filters.genres);
    if (newGenres.contains(genreId)) {
      newGenres.remove(genreId);
    } else {
      newGenres.add(genreId);
    }
    _updateFilters(filters.copyWith(genres: newGenres));
  }

  void _handleLanguageSelect(String code) {
    final filters = ref.read(exploreFiltersProvider);
    if (!filters.languages.contains(code)) {
      final newLangs = List<String>.from(filters.languages)..add(code);
      _updateFilters(filters.copyWith(languages: newLangs));
    }
    _langSearchController.clear();
    setState(() => _isLangOpen = false);
  }

  void _removeLanguage(String code) {
    final filters = ref.read(exploreFiltersProvider);
    final newLangs = List<String>.from(filters.languages)..remove(code);
    _updateFilters(filters.copyWith(languages: newLangs));
  }

  void _toggleWatchProvider(int providerId) {
    final filters = ref.read(exploreFiltersProvider);
    final newProviders = List<int>.from(filters.watchProviders);
    if (newProviders.contains(providerId)) {
      newProviders.remove(providerId);
    } else {
      newProviders.add(providerId);
    }
    _updateFilters(filters.copyWith(watchProviders: newProviders));
  }

  @override
  void dispose() {
    _langSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(exploreFiltersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Wrap(
                spacing: 32,
                runSpacing: 32,
                children: [
                   // Sort & Languages
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 64) / 3 : constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l10n.searchSortBy),
                        const SizedBox(height: 12),
                        _buildSortOption(l10n.searchMostPopular, 'popularity.desc', filters),
                        const SizedBox(height: 8),
                        _buildSortOption(l10n.searchHighestRated, 'vote_average.desc', filters),
                        const SizedBox(height: 8),
                        _buildSortOption(l10n.searchNewestReleases, 'primary_release_date.desc', filters),
                        const SizedBox(height: 32),
                        _buildSectionLabel(l10n.searchLanguages, subtitle: l10n.searchMatchAny),
                        const SizedBox(height: 12),
                        _buildLanguageSearch(),
                        const SizedBox(height: 12),
                        _buildSelectedLanguages(filters),
                      ],
                    ),
                  ),

                  // Genres
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 64) / 3 : constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l10n.searchGenres, subtitle: l10n.searchMatchAll),
                        const SizedBox(height: 16),
                        _buildGenreGrid(filters),
                        const SizedBox(height: 32),
                        _buildSectionLabel(l10n.searchWatchProviders),
                        const SizedBox(height: 12),
                        _buildWatchProviders(filters),
                      ],
                    ),
                  ),

                  // Sliders
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 64) / 3 : constraints.maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilterRangeSlider(
                          min: 0,
                          max: 10,
                          values: filters.rating,
                          onChanged: (v) => _updateFilters(filters.copyWith(rating: v)),
                          label: l10n.searchRating,
                          valueLabel: '${filters.rating.start.round()} - ${filters.rating.end.round()}',
                          icon: Icons.whatshot,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 1900,
                          max: 2025,
                          values: filters.year,
                          onChanged: (v) => _updateFilters(filters.copyWith(year: v)),
                          label: l10n.searchYearRange,
                          valueLabel: '${filters.year.start.round()} - ${filters.year.end.round()}',
                          icon: Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 0,
                          max: 20000,
                          values: filters.voteCount,
                          onChanged: (v) => _updateFilters(filters.copyWith(voteCount: v)),
                          label: l10n.searchVoteCount,
                          valueLabel: '${filters.voteCount.start.round()} - ${filters.voteCount.end.round() >= 20000 ? l10n.filterMax : filters.voteCount.end.round()}',
                          icon: Icons.thumb_up_outlined,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 0,
                          max: 240,
                          values: filters.runtime,
                          onChanged: (v) => _updateFilters(filters.copyWith(runtime: v)),
                          label: l10n.searchRuntime,
                          valueLabel: '${filters.runtime.start.round()}m - ${filters.runtime.end.round() >= 240 ? l10n.filterMax : '${filters.runtime.end.round()}m'}',
                          icon: Icons.access_time,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {String? subtitle}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.textWhite.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ],
    );
  }

  Widget _buildSortOption(String label, String value, ExploreFilters filters) {
    final isSelected = filters.sortBy == value;
    return HoverScale(
      onTap: () => _updateFilters(filters.copyWith(sortBy: value)),
      scale: 1.02,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textWhite : AppTheme.textWhite.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.textWhite : AppTheme.textWhite.withValues(alpha: 0.1),
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: AppTheme.textWhite.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textWhite.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreGrid(ExploreFilters filters) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TmdbConstants.genresList.map((g) {
        final genreId = g['id'] as int;
        final isSelected = filters.genres.contains(genreId);
        return HoverScale(
          onTap: () => _toggleGenre(genreId),
          scale: 1.08,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  g['name'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textWhite.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLanguageSearch() {
    return Column(
      children: [
        TextField(
          controller: _langSearchController,
          onTap: () => setState(() => _isLangOpen = true),
          onChanged: (v) => setState(() {}),
          style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchLanguagePlaceholder,
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textWhite)),
          ),
        ),
        if (_isLangOpen) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: _buildFilteredLanguages(),
          ),
        ],
      ],
    );
  }

  Widget _buildFilteredLanguages() {
    final query = _langSearchController.text.toLowerCase();
    final filtered = TmdbConstants.languagesList.where((l) =>
      l['name']!.toLowerCase().contains(query)).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(AppLocalizations.of(context)!.searchNoLanguagesFound, style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final lang = filtered[index];
        return ListTile(
          dense: true,
          title: Text(lang['name']!, style: const TextStyle(color: AppTheme.textSecondary)),
          onTap: () => _handleLanguageSelect(lang['code']!),
          hoverColor: AppTheme.textWhite.withValues(alpha: 0.05),
        );
      },
    );
  }

  Widget _buildSelectedLanguages(ExploreFilters filters) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.languages.map((code) {
        final lang = TmdbConstants.languagesList.firstWhere((l) => l['code'] == code);
        return Chip(
          label: Text(lang['name']!, style: const TextStyle(fontSize: 12)),
          backgroundColor: AppTheme.textWhite.withValues(alpha: 0.1),
          side: BorderSide(color: AppTheme.textWhite.withValues(alpha: 0.1)),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: () => _removeLanguage(code),
          labelStyle: const TextStyle(color: AppTheme.textWhite),
        );
      }).toList(),
    );
  }

  Widget _buildWatchProviders(ExploreFilters filters) {
    final providersAsync = ref.watch(watchProvidersListProvider);

    return providersAsync.when(
      data: (providers) {
        // Show only the most common/popular ones to avoid UI clutter
        final mainProviders = providers.where((p) {
           final name = p['provider_name']?.toString().toLowerCase() ?? '';
           return name.contains('netflix') || 
                  name.contains('disney') || 
                  name.contains('prime video') ||
                  name.contains('apple tv') ||
                  name.contains('now') ||
                  name.contains('rakuten');
        }).toList();

        if (mainProviders.isEmpty && providers.isNotEmpty) {
           // Fallback to first few if no major ones identified by keywords
           mainProviders.addAll(providers.take(6));
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mainProviders.map((p) {
            final id = p['provider_id'] as int;
            final isSelected = filters.watchProviders.contains(id);
            final imageUrl = "https://image.tmdb.org/t/p/original${p['logo_path']}";

            return HoverScale(
              onTap: () => _toggleWatchProvider(id),
              scale: 1.15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isSelected ? AppTheme.textWhite.withValues(alpha: 0.05) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.textWhite.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  PremiumHoverText(
                    text: p['provider_name'] ?? '',
                    width: 60,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
