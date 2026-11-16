import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';

/// Stateless, so it lives for the whole session.
final seriesDomainServiceProvider = Provider((ref) => SeriesDomainService());
