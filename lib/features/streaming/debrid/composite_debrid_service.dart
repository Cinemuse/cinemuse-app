import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/debrid/base_debrid_service.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';

/// Composite debrid service that orchestrates multiple providers (e.g. Real-Debrid, TorBox).
///
/// Features:
/// - Concurrent availability checks across all enabled providers.
/// - Prioritizes user's preferred provider.
/// - Intra-candidate failover: if provider A fails/rejects resolution, provider B is tried before candidate fallback.
/// - If every provider failed with an error, the last error is thrown
///   (as an [AppFailure]); `null` means "not available anywhere".
class CompositeDebridService implements BaseDebridService {
  static const String _tag = 'CompositeDebrid';

  final List<BaseDebridService> _services;
  final String preferredProvider;

  CompositeDebridService(
    List<BaseDebridService> services, {
    this.preferredProvider = 'Real-Debrid',
  }) : _services = services.where((s) => s.isEnabled).toList();

  @override
  String get name => _services.length == 1 ? _services.first.name : 'Debrid';

  @override
  bool get isEnabled => _services.isNotEmpty;

  @override
  Future<Map<String, bool>> checkAvailability(List<String> hashes) async {
    if (hashes.isEmpty || !isEnabled) return {};

    final detailed = await checkDetailedAvailability(hashes);
    return detailed.map(
      (hash, providers) => MapEntry(hash, providers.isNotEmpty),
    );
  }

  /// Returns a map of infoHash (lowercase) to the set of provider names that have it cached.
  Future<Map<String, Set<String>>> checkDetailedAvailability(
    List<String> hashes,
  ) async {
    if (hashes.isEmpty || !isEnabled) return {};

    final result = <String, Set<String>>{};
    for (final hash in hashes) {
      result[hash.toLowerCase()] = <String>{};
    }

    final futures = _services.map((service) async {
      try {
        final avail = await service.checkAvailability(hashes);
        avail.forEach((hash, isCached) {
          if (isCached) {
            result[hash.toLowerCase()]?.add(service.name);
          }
        });
      } catch (e, st) {
        // Safe to continue: candidates just won't be marked as cached here.
        AppLogger.warn(
          _tag,
          'checkAvailability failed on ${service.name}',
          error: e,
          stackTrace: st,
        );
      }
    });

    await Future.wait(futures);
    return result;
  }

  @override
  Future<ResolvedStream?> resolve(
    StreamCandidate candidate, {
    int? season,
    int? episode,
    int? fileId,
  }) async {
    if (!isEnabled) return null;

    final ordered = _orderServicesForCandidate(candidate);
    AppFailure? lastFailure;
    var hasAnyAnswered = false;

    for (final service in ordered) {
      try {
        AppLogger.debug(
          _tag,
          'Resolving on ${service.name}: ${candidate.title}',
        );
        final stream = await service.resolve(
          candidate,
          season: season,
          episode: episode,
          fileId: fileId,
        );

        hasAnyAnswered = true;
        if (stream != null) {
          AppLogger.debug(_tag, 'Resolved on ${service.name}');
          return stream;
        }
      } catch (e, st) {
        // Try the next provider; the failure is thrown below if none answers.
        AppLogger.warn(
          _tag,
          '${service.name} failed to resolve, trying the next provider',
          error: e,
          stackTrace: st,
        );
        lastFailure = e is AppFailure
            ? e
            : StreamingFailure(
                '${service.name} failed to resolve',
                cause: e,
                stackTrace: st,
              );
      }
    }

    if (!hasAnyAnswered && lastFailure != null) throw lastFailure;
    return null;
  }

  List<BaseDebridService> _orderServicesForCandidate(
    StreamCandidate candidate,
  ) {
    final cachedServices = <BaseDebridService>[];
    final otherServices = <BaseDebridService>[];

    for (final service in _services) {
      if (candidate.cachedOn[service.name] == true) {
        cachedServices.add(service);
      } else {
        otherServices.add(service);
      }
    }

    int prioritySort(BaseDebridService a, BaseDebridService b) {
      final aIsPref = a.name.toLowerCase() == preferredProvider.toLowerCase();
      final bIsPref = b.name.toLowerCase() == preferredProvider.toLowerCase();
      if (aIsPref && !bIsPref) return -1;
      if (!aIsPref && bIsPref) return 1;
      return 0;
    }

    cachedServices.sort(prioritySort);
    otherServices.sort(prioritySort);

    return [...cachedServices, ...otherServices];
  }
}
