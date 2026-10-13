import 'package:cinemuse_app/features/media/application/person_domain_service.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/domain/person.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A person's TMDB details. autoDispose: freed when the page closes, instead
/// of keeping every person opened for the whole session (REV-212).
final personDetailsProvider = FutureProvider.autoDispose
    .family<PersonDetails?, int>((ref, id) async {
      final tmdbService = ref.watch(tmdbServiceProvider);
      final map = await tmdbService.getPersonDetails(id);
      if (map == null) return null;
      return PersonDetails.fromTmdbMap(map);
    });

PersonDetails? _details(Ref ref, int personId) =>
    ref.watch(personDetailsProvider(personId)).valueOrNull;

/// The filmography, deduplicated, filtered and sorted once per person and
/// "show hidden" choice, not on every build (REV-212).
final personFilmographyProvider = Provider.autoDispose
    .family<List<PersonCredit>, ({int personId, bool showHidden})>((ref, key) {
      final details = _details(ref, key.personId);
      if (details == null) return const [];
      return PersonDomainService.processFilmography(
        cast: details.cast,
        crew: details.crew,
        showHidden: key.showHidden,
      );
    });

/// The person's best-known works.
final personKnownForProvider = Provider.autoDispose
    .family<List<PersonCredit>, int>((ref, personId) {
      final details = _details(ref, personId);
      if (details == null) return const [];
      return PersonDomainService.extractTopKnownFor(details.cast);
    });

/// How many of the person's titles the user has seen. Recomputed only when
/// the details or the watch history change.
final personSeenStatsProvider = Provider.autoDispose
    .family<PersonSeenStats, int>((ref, personId) {
      final details = _details(ref, personId);
      if (details == null) return const PersonSeenStats.empty();
      return PersonDomainService.calculateSeenStats(
        cast: details.cast,
        crew: details.crew,
        watchHistory: ref.watch(watchHistoryStoreProvider).valueOrNull ?? {},
      );
    });
