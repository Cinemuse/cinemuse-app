import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/updates/application/update_required_provider.dart';
import 'package:cinemuse_app/features/updates/data/app_config_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Answers like `app_config`: the stored minimum, or the read's failure.
class _FakeAppConfigRepository implements AppConfigRepository {
  final String? minimum;
  final AppFailure? error;

  _FakeAppConfigRepository({this.minimum, this.error});

  @override
  Future<String?> getMinimumAppVersion() async {
    final error = this.error;
    if (error != null) throw error;
    return minimum;
  }
}

void main() {
  Future<bool> isRequired(
    _FakeAppConfigRepository repository, {
    String version = '1.3.1',
    String build = '5',
  }) {
    final container = ProviderContainer(
      overrides: [
        appConfigRepositoryProvider.overrideWithValue(repository),
        installedVersionProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Cinemuse',
            packageName: 'com.cinemuse.app',
            version: version,
            buildNumber: build,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(updateRequiredProvider.future);
  }

  group('updateRequiredProvider (REV-306)', () {
    final cases = [
      (name: 'older than the minimum', minimum: '1.4.0', expected: true),
      (name: 'same build as the minimum', minimum: '1.3.1+5', expected: false),
      (name: 'newer than the minimum', minimum: '1.3.0', expected: false),
      (name: 'no minimum yet', minimum: '0.0.0', expected: false),
      (name: 'no row', minimum: null, expected: false),
    ];
    for (final c in cases) {
      test(c.name, () async {
        expect(
          await isRequired(_FakeAppConfigRepository(minimum: c.minimum)),
          c.expected,
        );
      });
    }

    test('offline: the app starts', () async {
      expect(
        await isRequired(
          _FakeAppConfigRepository(error: const NetworkFailure('offline')),
        ),
        isFalse,
      );
    });

    test('table missing (migration not pushed): the app starts', () async {
      expect(
        await isRequired(
          _FakeAppConfigRepository(
            error: const ServerFailure('relation not found'),
          ),
        ),
        isFalse,
      );
    });
  });
}
