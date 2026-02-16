import 'package:flutter/material.dart';

class ExploreFilters {
  final String sortBy;
  final List<int> genres;
  final List<String> languages;
  final RangeValues rating;
  final RangeValues year;
  final RangeValues voteCount;
  final RangeValues runtime;

  const ExploreFilters({
    this.sortBy = 'popularity.desc',
    this.genres = const [],
    this.languages = const [],
    this.rating = const RangeValues(0, 10),
    this.year = const RangeValues(1900, 2025),
    this.voteCount = const RangeValues(0, 20000),
    this.runtime = const RangeValues(0, 240),
  });

  ExploreFilters copyWith({
    String? sortBy,
    List<int>? genres,
    List<String>? languages,
    RangeValues? rating,
    RangeValues? year,
    RangeValues? voteCount,
    RangeValues? runtime,
  }) {
    return ExploreFilters(
      sortBy: sortBy ?? this.sortBy,
      genres: genres ?? this.genres,
      languages: languages ?? this.languages,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      voteCount: voteCount ?? this.voteCount,
      runtime: runtime ?? this.runtime,
    );
  }

  bool get isFiltered {
    return sortBy != 'popularity.desc' ||
        genres.isNotEmpty ||
        languages.isNotEmpty ||
        rating.start != 0 ||
        rating.end != 10 ||
        year.start != 1900 ||
        year.end != 2025 ||
        voteCount.start != 0 ||
        voteCount.end != 20000 ||
        runtime.start != 0 ||
        runtime.end != 240;
  }
}
