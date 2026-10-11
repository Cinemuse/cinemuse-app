import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListType.fromDb', () {
    test('reads the database names', () {
      expect(ListType.fromDb('watchlist'), ListType.watchlist);
      expect(ListType.fromDb('tier_list'), ListType.tierlist);
      expect(ListType.tierlist.dbName, 'tier_list');
    });

    test('an unknown type is a custom list instead of an error', () {
      expect(ListType.fromDb('ranking'), ListType.custom);
      expect(ListType.fromDb(null), ListType.custom);
    });
  });

  test('UserList.fromJson reads a tier list', () {
    final list = UserList.fromJson({
      'id': 'l1',
      'user_id': 'u1',
      'name': 'Best of',
      'type': 'tier_list',
      'created_at': '2026-10-12T10:00:00Z',
    });

    expect(list.type, ListType.tierlist);
  });
}
