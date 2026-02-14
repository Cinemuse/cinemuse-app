import 'dart:async';

import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: AppTheme.primary, // bg-primary
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: AppTheme.secondary.withOpacity(0.5),
              child: TextField(
                controller: _controller,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchPlaceholder,
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _controller.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () {
                          _controller.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                  filled: true,
                  fillColor: AppTheme.textWhite.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),

            // Results Grid
            Expanded(
              child: searchResultsAsync.when(
                data: (results) {
                  if (results.isEmpty && _controller.text.isNotEmpty) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)!.searchNoResults(_controller.text),
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    );
                  }
                  
                  if (results.isEmpty) {
                     return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.movie_filter_outlined, size: 64, color: AppTheme.textWhite.withOpacity(0.12)),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.searchEmptyStateTitle,
                            style: GoogleFonts.outfit(fontSize: 18, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 columns for desktop feel
                      childAspectRatio: 2 / 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      final posterPath = item['poster_path'];
                      final title = item['title'] ?? item['name'] ?? 'Unknown';
                      final year = (item['release_date'] ?? item['first_air_date'] ?? '').split('-').first;

                      return GestureDetector(
                        onTap: () {
                          // TODO: Navigate to Details Page
                          // ref.read(selectedMediaProvider.notifier).state = item;
                          // Navigator.push... 
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppTheme.surface,
                                  image: posterPath != null
                                      ? DecorationImage(
                                          image: NetworkImage('https://image.tmdb.org/t/p/w500$posterPath'),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: posterPath == null
                                    ? Center(child: Icon(Icons.broken_image, color: AppTheme.textWhite.withOpacity(0.24)))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)!.searchItemYear(year),
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('${AppLocalizations.of(context)!.commonError}: $e', style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
