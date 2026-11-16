-- Local DB check for the server's anime list (migrations
-- 20261024120000_anime_mapping_server, 20261027120000_anime_mapping_two_lists
-- and 20261030230000_anime_mapping_drop_ranges).
-- Users can't read or change the anime list tables nor call their functions;
-- anime-mapping (service_role) replaces the whole list at once with each
-- line's Kitsu id, exact TMDB episodes and the list that placed it, saves
-- both lists' sizes, and reads the list back without empty fields; the
-- hourly job calls only when the list is due and never without the Vault
-- secret.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/anime_mapping.sql
-- Any failed check stops with an error; success prints "anime_mapping: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000338', 'anime@test.local');

-- The Kitsu table, the one-argument replace and the old ranges column are
-- gone.
do $$
begin
  assert to_regclass('public.anime_kitsu') is null,
    'the Kitsu table is still there';
  assert to_regprocedure('public.replace_anime_mapping(jsonb)') is null,
    'the old replace_anime_mapping(jsonb) is still there';
  assert not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anime_mapping'
      and column_name = 'tmdb_ranges'),
    'the old tmdb_ranges column is still there';
end $$;

-- A signed-in user and a visitor can't touch any of it.
do $$
declare
  r text;
  err text;
  checks text[] := array[
    'select 1 from public.anime_mapping',
    'select 1 from public.anime_mapping_status',
    'insert into public.anime_mapping (anilist_id) values (1)',
    'update public.anime_mapping_status set last_error = ''x''',
    'select public.anime_mapping_rows()',
    'select public.replace_anime_mapping(''[]'', 1, 1)'];
  c text;
begin
  foreach r in array array['authenticated', 'anon'] loop
    execute format('set local role %I', r);
    perform set_config('request.jwt.claims',
      '{"sub":"00000000-0000-4000-8000-000000000338","role":"' || r || '"}',
      true);
    foreach c in array checks loop
      err := null;
      begin
        execute c;
      exception when insufficient_privilege then err := 'denied';
      end;
      assert err = 'denied', format('%s can run: %s', r, c);
    end loop;
    reset role;
  end loop;
end $$;

-- anime-mapping's side.
set local role service_role;

do $$
declare
  n integer;
begin
  n := public.replace_anime_mapping('[
    {"anilist_id": 2, "tmdb_show_id": 9, "placed_by": "fribb"},
    {"anilist_id": 1, "anidb_id": 5, "kitsu_id": 6, "tmdb_movie_id": 7,
     "placed_by": "fribb"},
    {"anilist_id": 2, "kitsu_id": 8, "tmdb_show_id": 10,
     "tmdb_episodes": [{"season": 1, "first": 25, "last": 37, "anime_first": 1},
                       {"season": 2, "first": 1}],
     "placed_by": "anibridge"}]', 1200, 1500);
  assert n = 2, 'an AniList id twice is not kept once';
  assert public.anime_mapping_rows() = '[
    {"anilist_id": 1, "anidb_id": 5, "kitsu_id": 6, "tmdb_movie_id": 7,
     "placed_by": "fribb"},
    {"anilist_id": 2, "kitsu_id": 8, "tmdb_show_id": 10,
     "tmdb_episodes": [{"season": 1, "first": 25, "last": 37, "anime_first": 1},
                       {"season": 2, "first": 1}],
     "placed_by": "anibridge"}]'::jsonb,
    'the rows are not read back in order, without empty fields, last one kept';
  assert (select refreshed_at = now() and tried_at = now() and row_count = 2
                 and last_error is null
                 and anibridge_count = 1200 and fribb_count = 1500
          from public.anime_mapping_status),
    'the refresh and the lists'' sizes are not saved in the status';

  n := public.replace_anime_mapping(
    '[{"anilist_id": 3, "tmdb_show_id": 11, "placed_by": "fix"}]', 1100, 1400);
  assert (select array_agg(anilist_id) from public.anime_mapping) = array[3],
    'the old list is not replaced';
  assert (select anibridge_count = 1100 and fribb_count = 1400
          from public.anime_mapping_status),
    'the lists'' new sizes are not saved';

  -- Only the two lists and our fixes can place an anime; a refused list
  -- leaves the one before it.
  begin
    perform public.replace_anime_mapping(
      '[{"anilist_id": 4, "tmdb_show_id": 12, "placed_by": "guess"}]', 1, 1);
    raise exception 'an unknown placed_by was accepted';
  exception when check_violation then null;
  end;
  assert (select array_agg(anilist_id) from public.anime_mapping) = array[3],
    'a refused list did not leave the one before it';
end $$;

reset role;

-- The hourly job.
do $$
declare
  cmd text := (select command from cron.job
               where jobname = 'refresh-anime-mapping');
  before bigint := (select count(*) from net.http_request_queue);
begin
  update public.anime_mapping_status
  set refreshed_at = now() - interval '21 hours',
      tried_at = now() - interval '2 hours';
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before,
    'the job called out without the project_url secret';

  perform vault.create_secret('http://127.0.0.1:9', 'project_url');
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before + 1,
    'the job did not call anime-mapping for an old list';
  assert (select url from net.http_request_queue order by id desc limit 1)
         = 'http://127.0.0.1:9/functions/v1/anime-mapping',
    'the job called the wrong URL';

  update public.anime_mapping_status
  set refreshed_at = now() - interval '19 hours';
  execute cmd;
  update public.anime_mapping_status
  set refreshed_at = now() - interval '21 hours',
      tried_at = now() - interval '30 minutes';
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before + 1,
    'the job called out for a fresh list or one tried in the last hour';
end $$;

select 'anime_mapping: ok';

rollback;
