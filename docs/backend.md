# Backend

The Supabase project behind Cinemuse. App side: [architecture.md](architecture.md).

## Local stack

Needs the Supabase CLI and Docker. `supabase start` / `supabase stop`. Studio: http://127.0.0.1:54323 · API: http://127.0.0.1:54321 · database: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`.

## Database

Public sign-up is off: new users are added in the dashboard (Authentication → Users). Every table has row-level security.

| Table | What it holds |
|---|---|
| `profiles` | One row per user. `preferences`: the settings, written only through `patch_preferences` with the changed keys |
| `user_secrets` | Anything with credentials (API keys, installed add-ons), written only through `patch_secrets` |
| `watch_history` | One row per title a user watched or is watching |
| `watch_logs` | One row per watch; saving one updates the title in `watch_history` |
| `lists`, `list_items` | The user's lists |
| `agenda_titles` | Every title someone follows, and when the agenda checks it next |
| `upcoming_agenda_cache` | The upcoming episodes and releases shown in the agenda |
| `media_cache` | Titles and posters, shared by everyone |
| `anime_mapping` | The anime mapping, used only by the server |
| `anime_mapping_status` | When the anime mapping was last refreshed and its last failure; signed-in users can read it |
| `server_addresses` | Addresses the app reads from the server instead of having them built in, so a moved service needs no release, and the name the app shows for each (`display_name`, so the code never names the sites); edited in the Table Editor |
| `api_keys` | Keys of outside services (e.g. TMDB) the app reads after sign-in; entered in the Table Editor, never in a migration |
| `app_config` | `min_app_version`: an older app shows "Update required" instead of starting |
| `reviews` | One row per film or series a user rated: the score from 1 to 10 and the review, seen only by that user |
| `user_stats` | A view, not a table: each user's watch totals for the profile page, worked out from `watch_logs` and the runtimes in `media_cache` |

- `profiles`, `watch_history` and `watch_logs` are live: a change on one device reaches the others at once. A table the app streams must be added to the `supabase_realtime` publication.
- The public `livetv` storage folder (the default playlist, its guide and the channel logos) is data, not schema, so it isn't in the migrations.

## Migrations

Migrations live in `supabase/migrations/`; the live schema is never changed by hand.

1. `supabase migration new <name>`, then write the SQL.
2. Test it on the local database inside `begin … rollback`.
3. `supabase db push --linked --dry-run` lists only the new file; then `supabase db push --linked`.
4. Commit the file. After the push: `supabase migration up --local`.

**New database functions:** after the push, check that each one is `security invoker`, has a fixed `search_path`, can't be run by `anon`, and adds no new advisor warning.

## Local SQL checks

- A prompt: `docker exec -i supabase_db_cinemuse-app psql -U postgres`; work inside `begin … rollback`.
- To act as a user: insert one into `auth.users`, then `set local role authenticated` and `set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true)`.
- Checks worth keeping go in `supabase/tests/<name>.sql`; each file's header says how to run it.

## Server functions

They live in `supabase/functions/`. Deploy one at a time: `supabase functions deploy <name> --use-api`. Secrets: `supabase secrets set`. Tests: `deno test supabase/functions/<name>`. Scheduled jobs run with pg_cron and read the project's address from the Vault secret `project_url`.

- **`anime-mapping`:** keeps the list that says which anime episode each TMDB episode is, rebuilt about once a day from two lists: anibridge-mappings for each anime's exact TMDB episodes, Fribb/anime-lists for its numbers on the other sites (Kitsu's among them) and the films. It stores only what a list states and never works out an end: an anime AniBridge lacks takes Fribb's start only when it is alone in its TMDB season, and double episodes are left out. Our fixes (`corrections.ts`) win over both; the refresh logs a fix the lists now agree with. A list that fails, or has under 90% of last time's anime, keeps the old list. Signed-in users only. `GET` with no parameters gives the whole list (the app keeps it as its offline copy); `GET ?tmdb_id=…&type=…&season=…&episode=…` answers which anime episode it is. The answer is the first line, by AniList id, whose TMDB episodes cover the episode, else none. The app's copy picks with the same rule when the server can't be reached; `known_cases.json` holds the cases both must answer the same.
- **`refresh-agenda`:** keeps the agenda up to date from TMDB. Following a title only marks it as due; a job every minute checks up to 50 due titles. Next check in a day, a week for old movies and ended series, an hour after a failure.
- **`live-tv`:** writes the default "Cinemuse IPTV" playlist and its TV guide as two public files, `livetv/playlist.m3u` and `livetv/epg.json`. The channels and the guide sources are in its code (`channels.ts`): a change is a code change and a deploy. Never rename a channel's `key`: apps match the guide on it. A channel can have several streams, the broadcaster's own first: the playlist writes one line per stream with the same name and the stream's source in `provider`, and the app merges them into one channel that moves to the next stream when one fails. Rai and Sky lines carry `cinemuse-ask`: the device asks the broadcaster for the real link at play time. An hourly job rewrites the playlist when it changed and refreshes one guide source (the most overdue); a source that fails keeps its programmes from the last file.

## Client library

`Supabase.initialize` gets the publishable key through `publishableKey`; in `.env` it keeps its old name, `SUPABASE_ANON_KEY`.
