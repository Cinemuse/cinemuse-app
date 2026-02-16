import 'dart:ui';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/details/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/details/person_details_screen.dart';
import 'package:cinemuse_app/features/search/application/search_provider.dart';
import 'package:cinemuse_app/features/search/application/search_state.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => const SearchOverlay(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    final currentQuery = ref.read(searchProvider).query;
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
       if (mounted) Navigator.of(context).pop();
    });
  }

  void _onMediaTap(Map<String, dynamic> media) {
     final type = media['media_type'] ?? media['type'] ?? 'movie';
     final id = media['id'].toString();
     
      Navigator.of(context).pop();

      if (type == 'person') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PersonDetailsScreen(personId: int.parse(id)),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaDetailsScreen(
              mediaId: id,
              mediaType: type == 'tv' || type == 'series' ? 'tv' : 'movie',
            ),
          ),
        );
     }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 0),
              child: Align(
                 alignment: Alignment.topCenter,
                 child: ScaleTransition(
                   scale: _scaleAnimation,
                   child: Material(
                     color: Colors.transparent,
                     child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
                      margin: const EdgeInsets.only(top: 40),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                               border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                            ),
                            child: Row(
                               children: [
                                  const Icon(LucideIcons.search, color: AppTheme.textMuted, size: 24),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _focusNode,
                                      cursorColor: Colors.white,
                                      style: const TextStyle(
                                        fontSize: 20, 
                                        color: Colors.white, 
                                        fontWeight: FontWeight.w300
                                      ),
                                      decoration: InputDecoration(
                                         hintText: l10n.searchPlaceholder,
                                         hintStyle: TextStyle(
                                           color: AppTheme.textMuted.withOpacity(0.5),
                                           fontSize: 20,
                                           fontWeight: FontWeight.w300,
                                         ),
                                         border: InputBorder.none,
                                         enabledBorder: InputBorder.none,
                                         focusedBorder: InputBorder.none,
                                         filled: false,
                                         contentPadding: EdgeInsets.zero,
                                         hoverColor: Colors.transparent,
                                      ),
                                      onChanged: (val) {
                                         ref.read(searchProvider.notifier).onQueryChanged(val);
                                      },
                                    ),
                                  ),
                                  if (searchState.status == SearchStatus.loading)
                                     const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)
                                     ),
                                  
                                  const SizedBox(width: 12),
                                  Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                                  const SizedBox(width: 12),
                                  
                                  IconButton(
                                     icon: const Icon(LucideIcons.x, color: AppTheme.textMuted),
                                     onPressed: _handleClose,
                                     tooltip: l10n.commonCancel,
                                  ),
                               ],
                            ),
                          ),
                          
                          Flexible(
                            child: Container(
                              color: Colors.black.withOpacity(0.2),
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.7,
                                minHeight: 200,
                              ),
                              child: _buildBody(searchState, l10n),
                            ),
                          ),
                        ],
                      ),
                   ),
                 ),
                 ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(SearchState state, AppLocalizations l10n) {
     if (state.query.isEmpty) {
        return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(LucideIcons.film, size: 24, color: Colors.white24),
                       SizedBox(width: 16),
                       Icon(LucideIcons.tv, size: 24, color: Colors.white24),
                       SizedBox(width: 16),
                       Icon(LucideIcons.user, size: 24, color: Colors.white24),
                    ],
                 ),
                 const SizedBox(height: 16),
                 const Text("Start typing to search...", style: TextStyle(color: AppTheme.textMuted)),
              ],
           ),
        );
     }
     
     if (state.status == SearchStatus.noResults) {
        return Center(
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(LucideIcons.search, size: 48, color: Colors.white12),
                 const SizedBox(height: 16),
                 Text(l10n.searchNoResults(state.query), style: const TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              ],
           ),
        );
     }
     
     return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
           maxCrossAxisExtent: 200,
           childAspectRatio: 0.67, 
           crossAxisSpacing: 16,
           mainAxisSpacing: 16,
        ),
        itemCount: state.results.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
           if (index == state.results.length) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
           }
           
           final item = state.results[index];
           final title = item['title'] ?? item['name'] ?? 'Unknown';
           final isPerson = item['media_type'] == 'person';
           final posterPath = isPerson ? item['profile_path'] : item['poster_path'];
           final releaseDate = isPerson ? item['known_for_department'] : (item['release_date'] ?? item['first_air_date']);
           final rating = isPerson ? null : (item['vote_average'] as num?)?.toDouble();

           return MediaCard(
              title: title,
              posterPath: posterPath,
              releaseDate: releaseDate,
              rating: rating,
              onTap: () => _onMediaTap(item),
           );
        },
     );
  }
}
