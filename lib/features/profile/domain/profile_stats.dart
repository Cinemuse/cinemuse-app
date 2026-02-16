class ProfileStats {
  final int totalMinutesWatched; // From DB or Calc
  final int totalEpisodes;
  final int totalMovies;
  
  // Period Stats
  final PeriodStats last7Days;
  final PeriodStats last30Days;
  final PeriodStats last365Days;

  final int totalSeries;
  final int totalSeasons;

  // Breakdown
  final int movieMinutes;
  final int seriesMinutes;

  ProfileStats({
    required this.totalMinutesWatched,
    required this.totalEpisodes,
    required this.totalMovies,
    required this.totalSeries,
    required this.totalSeasons,
    required this.last7Days,
    required this.last30Days,
    required this.last365Days,
    required this.movieMinutes,
    required this.seriesMinutes,
  });

  factory ProfileStats.empty() {
    return ProfileStats(
      totalMinutesWatched: 0,
      totalEpisodes: 0,
      totalMovies: 0,
      totalSeries: 0,
      totalSeasons: 0,
      last7Days: PeriodStats.empty(),
      last30Days: PeriodStats.empty(),
      last365Days: PeriodStats.empty(),
      movieMinutes: 0,
      seriesMinutes: 0,
    );
  }
}

class PeriodStats {
  final int totalMinutes;
  final int movieCount;
  final int episodeCount;

  PeriodStats({
    required this.totalMinutes,
    required this.movieCount,
    required this.episodeCount,
  });

  factory PeriodStats.empty() {
    return PeriodStats(totalMinutes: 0, movieCount: 0, episodeCount: 0);
  }
}
