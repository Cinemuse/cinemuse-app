enum ProviderStatus {
  searching,
  finished,
  failed,
}

class ProviderSearchStatus {
  final String providerName;
  final ProviderStatus status;
  final int resultsCount;
  final Duration timeElapsed;
  final String? errorMessage;

  const ProviderSearchStatus({
    required this.providerName,
    this.status = ProviderStatus.searching,
    this.resultsCount = 0,
    this.timeElapsed = Duration.zero,
    this.errorMessage,
  });

  ProviderSearchStatus copyWith({
    String? providerName,
    ProviderStatus? status,
    int? resultsCount,
    Duration? timeElapsed,
    String? errorMessage,
  }) {
    return ProviderSearchStatus(
      providerName: providerName ?? this.providerName,
      status: status ?? this.status,
      resultsCount: resultsCount ?? this.resultsCount,
      timeElapsed: timeElapsed ?? this.timeElapsed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
