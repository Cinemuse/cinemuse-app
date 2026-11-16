-- Local DB check for `complete_watch` (finishing a movie or episode in the
-- player). A title's watch_history row must never go away while it has
-- watch_logs: a second finish within 3 hours used to delete it.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/complete_watch.sql
-- Any failed check stops with an error; success prints "complete_watch: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000c1', 'complete-watch@test.local');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', true);

do $$
declare
  me constant uuid := '00000000-0000-4000-8000-0000000000c1';
  h record;
  logs integer;
begin
  -- 1. A movie played to the end.
  insert into public.watch_history
    (user_id, tmdb_id, media_type, season, episode, status, progress_seconds,
     total_duration)
  values (me, 900001, 'movie', 0, 0, 'watching', 5000, 6000);
  perform public.complete_watch(900001, 'movie', 0, 0, 5900, null, null, false, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900001;
  select count(*) into logs from public.watch_logs where user_id = me and tmdb_id = 900001;
  assert h.status = 'completed' and h.progress_seconds = 0, 'movie: not completed';
  assert logs = 1 and h.watch_count = 1, 'movie: not logged once';

  -- A later save after the end does nothing.
  perform public.complete_watch(900001, 'movie', 0, 0, 5950, null, null, false, true);
  select count(*) into logs from public.watch_logs where user_id = me and tmdb_id = 900001;
  assert logs = 1, 'movie: a later save logged it again';

  -- Jumped back during the credits (the player saves "watching"), then the
  -- end again within 3 hours: still completed, still one watch.
  update public.watch_history set status = 'watching', progress_seconds = 4000
  where user_id = me and tmdb_id = 900001;
  perform public.complete_watch(900001, 'movie', 0, 0, 5900, null, null, false, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900001;
  select count(*) into logs from public.watch_logs where user_id = me and tmdb_id = 900001;
  assert h is not null, 'movie: the second finish deleted its row';
  assert h.status = 'completed' and h.progress_seconds = 0, 'movie: second finish not completed';
  assert logs = 1 and h.watch_count = 1, 'movie: second finish counted twice';

  -- 2. The last episode of a series (no next episode), the same way.
  insert into public.watch_history
    (user_id, tmdb_id, media_type, season, episode, status, progress_seconds,
     total_duration)
  values (me, 900002, 'tv', 1, 8, 'watching', 1300, 1400);
  perform public.complete_watch(900002, 'tv', 1, 8, 1390, null, null, false, true);
  update public.watch_history set status = 'watching', progress_seconds = 1000
  where user_id = me and tmdb_id = 900002;
  perform public.complete_watch(900002, 'tv', 1, 8, 1390, null, null, false, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900002;
  assert h is not null, 'last episode: the second finish deleted its row';
  assert h.status = 'completed' and (h.season, h.episode) = (1, 8),
    'last episode: not completed at 1x8';

  -- 3. An episode with an aired next one: Continue Watching moves on.
  insert into public.watch_history
    (user_id, tmdb_id, media_type, season, episode, status, progress_seconds,
     total_duration)
  values (me, 900003, 'tv', 1, 1, 'watching', 1300, 1400);
  perform public.complete_watch(900003, 'tv', 1, 1, 1390, 1, 2, true, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900003;
  assert h.status = 'watching' and (h.season, h.episode) = (1, 2)
    and h.progress_seconds = 0, 'next episode: not moved on to 1x2';

  -- 4. A rewatch finished in the player keeps the earlier count.
  insert into public.watch_logs (user_id, tmdb_id, media_type, season, episode, logged_at)
  values (me, 900004, 'movie', 0, 0, now() - interval '2 days');
  update public.watch_history set status = 'watching', progress_seconds = 5000,
    last_watched_at = now() - interval '1 hour'
  where user_id = me and tmdb_id = 900004;
  perform public.complete_watch(900004, 'movie', 0, 0, 5900, null, null, false, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900004;
  assert h.status = 'completed' and h.watch_count = 2, 'rewatch: count not kept';

  -- 5. A dropped title stays dropped and isn't logged by a late save.
  insert into public.watch_history
    (user_id, tmdb_id, media_type, season, episode, status)
  values (me, 900005, 'tv', 1, 3, 'dropped');
  perform public.complete_watch(900005, 'tv', 1, 3, 1390, null, null, false, true);
  select * into h from public.watch_history where user_id = me and tmdb_id = 900005;
  select count(*) into logs from public.watch_logs where user_id = me and tmdb_id = 900005;
  assert h.status = 'dropped' and logs = 0, 'dropped: changed by a late save';
end $$;

select 'complete_watch: ok';

rollback;
