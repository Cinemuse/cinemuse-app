class PlaybackThresholds {
  /// Minimum time in seconds to track progress (Peeking state).
  static const int peekingSeconds = 120;
  
  /// Minimum percentage of duration to track progress (Peeking state).
  static const double peekingPercentage = 0.10;

  /// Seconds remaining to count as "Completed".
  static const int completionRemainingSeconds = 120;

  /// Percentage of duration to count as "Completed".
  static const double completionPercentage = 0.95;
}
