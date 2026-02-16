import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import '../../../../core/presentation/theme/app_theme.dart';
import '../../../../core/constants/tmdb_constants.dart';
import 'explore_filters.dart';
import 'filter_range_slider.dart';

class ExploreFilterPanel extends StatefulWidget {
  final bool show;
  final ExploreFilters filters;
  final ValueChanged<ExploreFilters> onChanged;
  final VoidCallback onClear;

  const ExploreFilterPanel({
    super.key,
    required this.show,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<ExploreFilterPanel> createState() => _ExploreFilterPanelState();
}

class _ExploreFilterPanelState extends State<ExploreFilterPanel> {
  final TextEditingController _langSearchController = TextEditingController();
  bool _isLangOpen = false;

  void _toggleGenre(int genreId) {
    final newGenres = List<int>.from(widget.filters.genres);
    if (newGenres.contains(genreId)) {
      newGenres.remove(genreId);
    } else {
      newGenres.add(genreId);
    }
    widget.onChanged(widget.filters.copyWith(genres: newGenres));
  }

  void _handleLanguageSelect(String code) {
    if (!widget.filters.languages.contains(code)) {
      final newLangs = List<String>.from(widget.filters.languages)..add(code);
      widget.onChanged(widget.filters.copyWith(languages: newLangs));
    }
    _langSearchController.clear();
    setState(() => _isLangOpen = false);
  }

  void _removeLanguage(String code) {
    final newLangs = List<String>.from(widget.filters.languages)..remove(code);
    widget.onChanged(widget.filters.copyWith(languages: newLangs));
  }

  @override
  void dispose() {
    _langSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 32),
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
                        _buildSortOption(l10n.searchMostPopular, 'popularity.desc'),
                        const SizedBox(height: 8),
                        _buildSortOption(l10n.searchHighestRated, 'vote_average.desc'),
                        const SizedBox(height: 8),
                        _buildSortOption(l10n.searchNewestReleases, 'primary_release_date.desc'),
                        const SizedBox(height: 32),
                        _buildSectionLabel(l10n.searchLanguages, subtitle: l10n.searchMatchAny),
                        const SizedBox(height: 12),
                        _buildLanguageSearch(),
                        const SizedBox(height: 12),
                        _buildSelectedLanguages(),
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
                        _buildGenreGrid(),
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
                          values: widget.filters.rating,
                          onChanged: (v) => widget.onChanged(widget.filters.copyWith(rating: v)),
                          label: l10n.searchRating,
                          valueLabel: '${widget.filters.rating.start.round()} - ${widget.filters.rating.end.round()}',
                          icon: Icons.whatshot,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 1900,
                          max: 2025,
                          values: widget.filters.year,
                          onChanged: (v) => widget.onChanged(widget.filters.copyWith(year: v)),
                          label: l10n.searchYearRange,
                          valueLabel: '${widget.filters.year.start.round()} - ${widget.filters.year.end.round()}',
                          icon: Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 0,
                          max: 20000,
                          values: widget.filters.voteCount,
                          onChanged: (v) => widget.onChanged(widget.filters.copyWith(voteCount: v)),
                          label: l10n.searchVoteCount,
                          valueLabel: '${widget.filters.voteCount.start.round()} - ${widget.filters.voteCount.end.round() >= 20000 ? 'Max' : widget.filters.voteCount.end.round()}',
                          icon: Icons.thumb_up_outlined,
                        ),
                        const SizedBox(height: 32),
                         FilterRangeSlider(
                          min: 0,
                          max: 240,
                          values: widget.filters.runtime,
                          onChanged: (v) => widget.onChanged(widget.filters.copyWith(runtime: v)),
                          label: l10n.searchRuntime,
                          valueLabel: '${widget.filters.runtime.start.round()}m - ${widget.filters.runtime.end.round() >= 240 ? 'Max' : widget.filters.runtime.end.round().toString() + 'm'}',
                          icon: Icons.access_time,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {String? subtitle}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ],
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = widget.filters.sortBy == value;
    return GestureDetector(
      onTap: () => widget.onChanged(widget.filters.copyWith(sortBy: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.1)),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TmdbConstants.genresList.map((g) {
        final genreId = g['id'] as int;
        final isSelected = widget.filters.genres.contains(genreId);
        return GestureDetector(
          onTap: () => _toggleGenre(genreId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  g['name'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const CircleAvatar(radius: 3, backgroundColor: AppTheme.accent),
                ],
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
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchLanguagePlaceholder,
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
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
          title: Text(lang['name']!, style: const TextStyle(color: Colors.white70)),
          onTap: () => _handleLanguageSelect(lang['code']!),
          hoverColor: Colors.white.withOpacity(0.05),
        );
      },
    );
  }

  Widget _buildSelectedLanguages() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.filters.languages.map((code) {
        final lang = TmdbConstants.languagesList.firstWhere((l) => l['code'] == code);
        return Chip(
          label: Text(lang['name']!, style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.white.withOpacity(0.1),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: () => _removeLanguage(code),
          labelStyle: const TextStyle(color: Colors.white),
        );
      }).toList(),
    );
  }
}
