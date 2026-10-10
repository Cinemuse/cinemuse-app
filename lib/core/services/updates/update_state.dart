import 'package:dio/dio.dart';

enum UpdateStatus {
  initial,
  checking,
  available,
  downloading,
  readyToInstall,
  upToDate,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final String? latestVersion;
  final String? currentVersion;
  final double progress;
  final String? error;
  final String? errorKey;
  final Map<String, String>? errorArgs;
  final String? downloadUrl;

  /// The release's `SHA256SUMS` file; without it Windows refuses to update.
  final String? checksumUrl;
  final String? releaseNotes;
  final CancelToken? cancelToken;

  UpdateState({
    required this.status,
    this.latestVersion,
    this.currentVersion,
    this.progress = 0,
    this.error,
    this.errorKey,
    this.errorArgs,
    this.downloadUrl,
    this.checksumUrl,
    this.releaseNotes,
    this.cancelToken,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    String? latestVersion,
    String? currentVersion,
    double? progress,
    String? error,
    String? errorKey,
    Map<String, String>? errorArgs,
    String? downloadUrl,
    String? checksumUrl,
    String? releaseNotes,
    CancelToken? cancelToken,
    bool clearCancelToken = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      latestVersion: latestVersion ?? this.latestVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      errorKey: errorKey ?? this.errorKey,
      errorArgs: errorArgs ?? this.errorArgs,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      checksumUrl: checksumUrl ?? this.checksumUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      cancelToken: clearCancelToken ? null : (cancelToken ?? this.cancelToken),
    );
  }
}
