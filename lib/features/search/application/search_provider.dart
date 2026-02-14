import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  
  // Debounce could be added here, but for simplicity we'll rely on UI logic or simple delay
  // For better UX, we might want to debounce the input in the UI widget instead.
  
  final tmdbService = ref.read(tmdbServiceProvider);
  return tmdbService.searchMulti(query);
});
