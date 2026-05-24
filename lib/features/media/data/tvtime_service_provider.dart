import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/tvtime_service.dart';

/// Provides the [TvTimeService] singleton.
final tvTimeServiceProvider = Provider<TvTimeService>((ref) {
  return TvTimeService(ref.read(dioProvider));
});
