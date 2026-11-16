/// The one way live TV cleans channel names and guide ids: the playlist
/// reader, the join of all playlists and the guide lookup all use it, so a
/// channel is grouped and matched by the same rules everywhere.
abstract final class ChannelName {
  static final _qualityWords = RegExp(r'\b(fhd|uhd|hd|sd|4k|1080p|720p)\b');
  static final _countryWords = RegExp(r'\b(italia|italy)\b');
  // Letters of any language stay ("Rai Südtirol"); "+" stays for "+1".
  static final _symbols = RegExp(r'[^\p{L}\p{N}\s+]', unicode: true);
  static final _plus = RegExp(r'\s*\+\s*');
  static final _spaces = RegExp(r'\s+');
  static final _hoursLater = RegExp(r'(?:^|\s)\+([1-9])$');
  static final _domainSuffix = RegExp(r'\.(it|ch|com|eu)$');
  static final _nonAlphanumeric = RegExp(r'[^a-z0-9]');
  static final _idHoursLater = RegExp(r'(\+|plus|piu)[1-9]');
  // Each accented letter and, at the same place, its plain one.
  static const _accented = 'àáâäãåèéêëìíîïòóôöõùúûüçñ';
  static const _plain = 'aaaaaaeeeeiiiiooooouuuucn';
  static final _accentedLetter = RegExp('[$_accented]');

  /// The id of the row a channel belongs to, also used to save favourites
  /// and recents: `name:<name without quality words>`. Two channels sharing
  /// a guide keep their own rows when their names differ (regional Rai 3,
  /// "+1"); the guide id is only the fallback for a channel with no name.
  /// Never the number: without `tvg-chno` it is the position in the file,
  /// so it changes when the provider adds a channel (REV-113).
  static String rowId(String name, String? epgId) {
    final key = rowKey(name);
    if (key.isNotEmpty) return 'name:$key';
    final id = epgId?.trim().toLowerCase() ?? '';
    return id.isNotEmpty ? 'epg:$id' : 'name:';
  }

  /// "Rai 1 HD" and "rai 1" give "rai 1"; "Canale 5+1" gives "canale 5 +1".
  static String rowKey(String name) => name
      .toLowerCase()
      .replaceAll(_qualityWords, '')
      .replaceAll(_symbols, '')
      .replaceAll(_plus, ' +')
      .replaceAll(_spaces, ' ')
      .trim();

  /// A guide key: lowercase, no domain ending, letters and digits only, so
  /// the id "Rai1.it" and the name "Rai 1" both give "rai1".
  static String guideKey(String text) => _withoutAccents(
    text.toLowerCase(),
  ).trim().replaceAll(_domainSuffix, '').replaceAll(_nonAlphanumeric, '');

  /// The keys a channel name is looked up by in the guide, best first. The
  /// exact name comes first: "Sky Italia News" would lose "italia" later.
  static List<String> guideKeysForName(String name) {
    final key = rowKey(name);
    return {
      name.trim().toLowerCase(),
      guideKey(key),
      guideKey(key.replaceAll(_countryWords, '')),
    }.where((k) => k.isNotEmpty).toList();
  }

  /// How many hours later a "+1" or "+2" channel airs the same programmes,
  /// or 0.
  static int hoursLater(String name) {
    final match = _hoursLater.firstMatch(rowKey(name));
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  /// "Canale 5 +1" without its "+1": the name of the channel it repeats.
  static String withoutHoursLater(String name) =>
      rowKey(name).replaceFirst(_hoursLater, '').trim();

  /// Whether a guide id is a "+1" channel's own ("Canale5+1.it",
  /// "Canale5Plus1.it"), so its times are already the later ones.
  static bool idIsHoursLater(String epgId) =>
      _idHoursLater.hasMatch(_withoutAccents(epgId.toLowerCase()));

  static String _withoutAccents(String text) => text.replaceAllMapped(
    _accentedLetter,
    (m) => _plain[_accented.indexOf(m.group(0)!)],
  );
}
