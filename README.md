# Cinemuse

A personal cinema guide: keep track of every movie, series and anime you watch, play them, and watch live TV, all in one app.

It runs on **Android phones, Android TV, Windows and Linux**, with one layout that adapts to the screen. Every screen works with a mouse, a keyboard, touch or a TV remote.

## What you can do

- **Find something to watch.** Home shows what you're in the middle of (Continue Watching), popular and new titles, your pinned lists and the sport schedule. Explore browses by genre, year, language and streaming service. Search keeps your recent searches.
- **Read about it.** Every movie, show and person has a page: details, cast, seasons and episodes (specials included), photos, the trailer, and reviews from popular review sites.
- **Track it.** Tick movies and episodes as watched, log rewatches, drop a show you gave up on. Continue Watching always points at the next episode. The Library page has your stats, your full watch history, your lists, and an agenda of upcoming episodes and releases. Everything is saved on your account and shows on every device.
- **Play it.** Cinemuse searches your Stremio add-ons (with Real-Debrid or TorBox) and its built-in sources, puts the best stream for your language and quality first, and moves to the next one by itself if a stream fails. Pick the audio track and the subtitles (also from OpenSubtitles), change how subtitles look, and pick up where you left off.
- **Watch live TV.** The built-in "Cinemuse IPTV" playlist has the Italian free-to-air channels with a TV guide. Add your own M3U playlists and guides, keep favourites, filter by category, type a channel number on the remote. On a phone the channel plays in a small player above the list.
- **Stay up to date.** The app updates itself from this repository's releases.

## How it behaves

- **Opening a page never marks anything as watched.**
- **A watch counts only if you watched it.** Finishing in the player counts; skipping to the end doesn't. A rewatch counts, unless the same movie or episode was logged in the last 3 hours.
- **Specials are extras:** they never count toward a show's progress.
- **Dropped is a label, not a list:** a dropped title comes back only through Restore.
- **No internet, nothing saved.** A tick or a list change with no connection is refused with a message; nothing is queued on the device.
- **For anime, a wrong episode is worse than none.** Sources are matched by the anime's ids, never by title alone, and never fall back to another episode.
- **The right file or nothing.** In a torrent with many files, the app never guesses: if it can't tell which file is the episode, it tries the next source.
- **A debrid switch covers its add-ons too:** turning off Real-Debrid also skips the add-ons that use a Real-Debrid key.
- **The mouse and the remote don't get in each other's way.** The mouse makes an item grow; the keys also draw a white focus ring, shown only after a key is pressed. Pink text means "this is what you click".
- **The built-in playlist and guide are always there:** they can't be removed, only switched off. Guides are managed like playlists: a list of links and files, each with its own switch.

## Install

Download the latest release from the Releases page: the `.apk` for Android (phone and TV), the `.zip` for Windows, the `.tar.gz` for Linux. Accounts are created by the owner: there is no public sign-up.

On Windows and Linux, unpack it into a folder of your own and open the app from there; it updates itself in that folder, with no admin password. On Linux it adds itself to your applications menu, and it needs the system's video engine, installed once (on Debian and Ubuntu: `sudo apt install libmpv2`).

## Build it yourself

1. Install [FVM](https://fvm.app). The Flutter version is pinned in `.fvmrc`; always run Flutter through `fvm`.
2. Create `.env` in this folder (it is bundled into the app and never committed):

   ```
   SUPABASE_URL=
   SUPABASE_ANON_KEY=
   ```

   The TMDB key is not here: the app reads it from the `api_keys` table after sign-in.

3. `fvm flutter pub get`, then `fvm flutter run`.

Built with Flutter, Riverpod, Supabase, Drift and media_kit. In English and Italian.

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md): how to work on the code: commands, tests, code rules, commits, releases.
- [docs/architecture.md](docs/architecture.md): how the code is organised.
- [docs/backend.md](docs/backend.md): the server: database, server functions, migrations.
