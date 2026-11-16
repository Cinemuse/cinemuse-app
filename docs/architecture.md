# Architecture

How the code is organised. Code rules: [CONTRIBUTING.md](../CONTRIBUTING.md). Server: [backend.md](backend.md).

## Stack

Flutter (pinned with FVM) for Android, Windows and Linux · Riverpod for state · Supabase for accounts, the database and server functions · Drift for the local database · Dio for HTTP · media_kit for playback (with patched copies of three of its packages in `packages/`: the video view, and the Windows and Android engines, swapped for newer or fuller builds; the reasons are in `pubspec.yaml`).

## Folders

| Folder | What it holds |
|---|---|
| `lib/core/` | App-wide code: local database, network, services, errors, theme |
| `lib/features/<name>/` | One folder per area: `auth`, `navigation`, `home`, `explore`, `search`, `media` (title and person pages, tracking, comments), `profile` (the Library page: lists, history, stats, agenda), `live_tv`, `video_player`, `streaming` (finding and ranking streams, debrid, anime mapping, subtitles), `settings`, `updates` |
| `lib/shared/widgets/` | Reusable widgets |
| `lib/l10n/` | Translations |
| `test/`, `integration_test/` | Tests |
| `supabase/` | Migrations, server functions, SQL checks |

## Layers

Each feature is split into layers, and each one only uses the ones below it:

```
presentation/  widgets
application/   providers and notifiers
data/          repositories, API clients, local database
domain/        models
```

A shared widget never imports a feature: it takes callbacks or a small interface the feature implements.

## From "Play" to the video

1. The player asks `UnifiedStreamResolver` for streams of the title (or episode).
2. The resolver asks every source at once: the Stremio add-ons, the built-in sources, and for anime the anime sources (which first look up the right anime episode in the anime mapping).
3. The results are filtered and ranked (`streaming/ranking/`): language first, then quality.
4. The best one is resolved into a playable link: a debrid service turns a torrent into a link, picking the right file.
5. media_kit plays it. If it fails, the player moves on to the next stream; a sound track the engine can't decode first makes it try the file's other sound tracks. A stream's name can call subtitles "ITA", so once a stream plays the player reads its sound tracks: when they all name a language and none is the preferred one, it moves on to the next stream whose name says that language. A stream the user picked stays, and so does the last one when no other claims the language; a message says so.

Live TV is simpler: the channel's links come from the playlist, tried in its order; some channels ask their broadcaster for the real link at play time (`LiveLinkResolver`). A link is recognised by the parts of its address (site, port, path, query: `StreamAddress`), never by words found anywhere in it. A playlist can give a channel its own headers (a Referer or a User-Agent, in VLC's `#EXTVLCOPT`, TiviMate's `#EXTHTTP` or Kodi's `|` form); they are sent with the stream and win over the app's own. Channel names are cleaned one way everywhere (`ChannelName`): channels are grouped into one row by their name without quality words ("Rai 1" and "Rai 1 HD" are one row), so channels sharing a guide keep their own rows (regional Rai 3, "+1"). A channel finds its programmes in the guide by its id, then its name (an XMLTV guide's own names for its channels count too), then its number, but only a number the guide itself sends (the Cinemuse guide does): the app keeps no table of channel numbers. An XMLTV guide is read with an XML reader (`EpgParser`) that skips a broken spot and reads on. A "+1" channel that borrows the normal channel's guide shows it an hour later. Playlists and guides are kept the same way (`LiveTvSourcesNotifier`): the Cinemuse one first, then the user's own, each on or off. Every guide that is on is loaded, each with its own cache; when two know the same channel, the one higher in the list wins. A playlist or guide that fails (a download error, or nothing in it) never stops the others: each load keeps the failed ones with the reason (`LiveTvLoad`), and a failed guide or downloaded playlist shows its saved copy (a playlist's last good download is kept in the app's folder, `PlaylistCopyStorage`, so it also covers the app's start), so a failed Refresh never empties the list. Opening the Live TV tab, and Refresh, say which ones failed; their rows in Playlists & EPGs say why. A channel number typed on a remote or keyboard works one way in the guide, the channel list and the player (`ChannelNumberEntryNotifier`), and the guide and the player show it while it is typed (`NumberInputOsd`).

A live stream often holds several picture sizes. mpv opens the biggest and never adapts by itself, and the app doesn't either: a new size reopens the stream (switching it in place froze the picture), which jumps back to live and drops what was loaded. So `LivePictureSizeSwitcher` only changes size when the user picks one; when the stream keeps buffering it suggests a lower size, once per channel. The loading after a seek doesn't count as buffering.

## Errors

Services and repositories throw an `AppFailure` (`core/error/app_failure.dart`). The UI turns it into translated text through `errorMapperProvider`.

## Data

- **A title is its TMDB id + media type,** because TMDB's movie and TV ids overlap.
- **Account data** lives in Supabase and reaches other devices live; the streams are wrapped in `reconnectingStream`, which reconnects after a drop. **Device-only** data: the local database (e.g. the anime mapping's offline copy) and SharedPreferences (device settings).
- `watchHistoryRevisionProvider` changes whenever the watch history changes: watch it to reload after a watch.
- **The player checks HTTPS certificates** against `assets/certs/cacert.pem` (Mozilla's list, from curl), because media_kit can't read the system's list on Windows or Android. A test fails when the file is a year old: download the new one.

## UI building blocks

- **Theme:** `AppTheme` (colours, text styles; every warning uses `warning`, and only warnings do). **Sizes:** `Breakpoints`.
- **Remote and keyboard:** `DpadFocusable` makes a control focusable and pressable with Enter. Every text box but the main search is a `DpadTextBox`: the arrows stop on it with no keyboard, Enter starts typing, Enter or Back stops. The focus ring is defined once in `FocusRing`; items get it through `DpadFocusable`, `CardFocusBorder`, `FocusRingFollower` or `AppPopupMenuItem`.
- **Sheets:** `AppBottomSheet`. **Errors on screen:** `ErrorViewState` (full screen), `ErrorCard` (inline), `AppSnackBar` (short message; `showUndo` after a removal).
- **Settings rows:** `settings_widgets.dart`. **Scrolling:** `AppScrollBehavior`.
- `StatePreview` is used only by the brand page, to draw hover and focus without a mouse.
