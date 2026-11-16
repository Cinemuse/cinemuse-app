/// An address the app reads from the server's `server_addresses` table, by
/// the row's `key`. Never change a key: released apps look for it.
///
/// The sites whose names stay out of the public repo have random codes and
/// no built-in copy; the name the app shows for them comes from the row's
/// `display_name`. The other services keep a plain key and a built-in copy,
/// used when the server's list doesn't have them.
enum ServerAddress {
  movieSite('kzt5q9nii880'),
  animeSite('6bmwcfdwmcna'),
  sportSchedule('5d0pto4ic5df'),
  animeTorrents('l39zzf5nvm89'),
  reviews('b4hqtew4040c'),
  kitsu('kitsu_api', builtIn: 'https://kitsu.app/api/edge'),
  updateRepo(
    'update_repo',
    builtIn: 'https://api.github.com/repos/Cinemuse/cinemuse-app',
  );

  const ServerAddress(this.key, {this.builtIn});

  final String key;
  final String? builtIn;
}

/// Gets the current address list; throws an `AppFailure` when there is none.
typedef ServerAddressesLoader = Future<ServerAddresses> Function();

/// The addresses as the server lists them (STR-08), with the name shown for
/// each.
///
/// A hidden site missing here means its source finds nothing.
class ServerAddresses {
  final Map<String, String> _addresses;
  final Map<String, String> _names;

  const ServerAddresses(this._addresses, [this._names = const {}]);

  static const empty = ServerAddresses({});

  /// Reads the table's rows, skipping any that isn't an `https` address with
  /// a host (a typo in the Table Editor must not reach the app).
  factory ServerAddresses.fromRows(Iterable<Object?> rows) {
    final addresses = <String, String>{};
    final names = <String, String>{};
    for (final row in rows.whereType<Map>()) {
      final key = row['key'];
      final address = row['address'];
      if (key is! String || address is! String) continue;
      final uri = Uri.tryParse(address.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      addresses[key] = address.trim();
      final name = row['display_name'];
      if (name is String && name.trim().isNotEmpty) names[key] = name.trim();
    }
    return ServerAddresses(addresses, names);
  }

  /// The rows again, as [ServerAddresses.fromRows] reads them.
  List<Map<String, String>> toRows() => [
    for (final MapEntry(:key, value: address) in _addresses.entries)
      {'key': key, 'address': address, 'display_name': ?_names[key]},
  ];

  /// The address as written in the table (a whole page for
  /// [ServerAddress.sportSchedule]), else the built-in copy.
  String? address(ServerAddress site) => _addresses[site.key] ?? site.builtIn;

  /// The address without a trailing slash, to append paths to.
  String? baseUrl(ServerAddress site) =>
      address(site)?.replaceFirst(RegExp(r'/+$'), '');

  /// The name shown for [site], empty when the table has none.
  String name(ServerAddress site) => _names[site.key] ?? '';
}
