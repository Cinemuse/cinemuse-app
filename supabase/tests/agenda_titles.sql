-- Local DB check for REV-292 (migration 20261020163441_agenda_titles).
-- Following a title marks it due without any HTTP call (a 150-episode
-- "Mark all" included), users can only add titles, refresh-agenda's two
-- functions claim and finish titles, and the cron job calls nothing
-- without the Vault secret.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/agenda_titles.sql
-- Any failed check stops with an error; success prints "agenda_titles: ok".

begin;

-- Only this test's titles.
delete from public.agenda_titles;
delete from public.upcoming_agenda_cache;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000292', 'rev292@test.local');

create temp table http_calls_before as
  select count(*) as n from net.http_request_queue;
grant select on http_calls_before to authenticated;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000292","role":"authenticated"}', true);

-- "Mark all" on a show: 150 episodes in one call.
select count(*) from public.log_episodes(5920, (
  select jsonb_agg(jsonb_build_object('season', 1, 'episode', e))
  from generate_series(1, 150) e));

-- A movie on the watchlist, a watched movie, and the same show again.
insert into public.list_items (list_id, tmdb_id, media_type, sort_order)
select id, 27205, 'movie', 0 from public.lists limit 1;
insert into public.list_items (list_id, tmdb_id, media_type, sort_order)
select id, 5920, 'tv', 1 from public.lists limit 1;
select count(*) from public.log_movie_watch(603, now(), true);

-- A user can't read, change or remove the list, nor pick a due date.
do $$
declare
  err text;
begin
  begin
    perform 1 from public.agenda_titles;
  exception when insufficient_privilege then err := 'denied';
  end;
  assert err = 'denied', 'a user can read agenda_titles';
  err := null;
  begin
    insert into public.agenda_titles (tmdb_id, media_type, due_at)
    values (1, 'tv', now() + interval '1 year');
  exception when insufficient_privilege then err := 'denied';
  end;
  assert err = 'denied', 'a user can set due_at';
  err := null;
  begin
    delete from public.agenda_titles;
  exception when insufficient_privilege then err := 'denied';
  end;
  assert err = 'denied', 'a user can delete from agenda_titles';
  err := null;
  begin
    perform public.claim_due_agenda_titles(50);
  exception when insufficient_privilege then err := 'denied';
  end;
  assert err = 'denied', 'a user can claim titles';
  err := null;
  begin
    perform public.finish_agenda_check(1, 'tv', null, '{}', 24, null);
  exception when insufficient_privilege then err := 'denied';
  end;
  assert err = 'denied', 'a user can write agenda rows';
end $$;

reset role;

do $$
begin
  assert (select array_agg(tmdb_id || ' ' || media_type order by tmdb_id)
          from public.agenda_titles)
         = array['603 movie', '5920 tv', '27205 movie'],
    'the followed titles are not on the list once each';
  assert (select count(*) from net.http_request_queue)
         = (select n from http_calls_before),
    'following a title made an HTTP call';
  assert not exists (select 1 from cron.job where jobname = 'invoke-sync-agenda'),
    'the old nightly job is still there';
  assert to_regprocedure('public.trigger_sync_agenda()') is null,
    'the old sync''s trigger function is still there';
end $$;

-- refresh-agenda's side (service_role).
insert into public.agenda_titles (tmdb_id, media_type) values (999, 'tv');
insert into public.upcoming_agenda_cache (tmdb_id, media_type, event_data)
values (999, 'tv', '{}'), (5920, 'tv', '{"old": true}');

set local role service_role;

create temp table claimed as
  select * from public.claim_due_agenda_titles(2);

do $$
begin
  -- 999 is followed by nobody: it leaves. 603 is a watched movie: it
  -- stays (the agenda reads the whole history).
  assert (select count(*) from claimed) = 2, 'the batch size is not kept';
  assert not exists (select 1 from public.agenda_titles where tmdb_id = 999),
    'an unfollowed title stays on the list';
  assert exists (select 1 from public.agenda_titles where tmdb_id = 603),
    'a watched movie left the list';
  assert not exists (select 1 from public.upcoming_agenda_cache where tmdb_id = 999),
    'an unfollowed title keeps its agenda row';
  assert (select count(*) from public.agenda_titles
          where due_at between now() + interval '9 minutes'
                           and now() + interval '11 minutes') = 2,
    'claimed titles are not held for 10 minutes';
  -- Of the three followed titles, a second run gets only the one left.
  assert (select array_agg(c.tmdb_id) from public.claim_due_agenda_titles(50) c)
         = (select array_agg(a.tmdb_id) from public.agenda_titles a
            where (a.tmdb_id, a.media_type) not in (select * from claimed)),
    'a second run claimed held titles';
end $$;

-- Saved, failed, removed, and a title gone meanwhile.
select public.finish_agenda_check(27205, 'movie', '2026-11-01', '{"title": "x"}', 24, null);
select public.finish_agenda_check(5920, 'tv', null, null, 1, 'TMDB answered 500');
select public.finish_agenda_check(42, 'tv', '2026-11-01', '{}', 24, null);

do $$
begin
  assert (select event_data from public.upcoming_agenda_cache where tmdb_id = 27205)
         = '{"title": "x"}', 'a check was not saved';
  assert (select checked_at is not null and last_error is null
                 and due_at between now() + interval '23 hours'
                                and now() + interval '25 hours'
          from public.agenda_titles where tmdb_id = 27205),
    'a saved title is not due again in 24 hours';
  assert (select event_data from public.upcoming_agenda_cache where tmdb_id = 5920)
         = '{"old": true}', 'a failed check changed the agenda row';
  assert (select checked_at is null and last_error = 'TMDB answered 500'
                 and due_at between now() + interval '59 minutes'
                                and now() + interval '61 minutes'
          from public.agenda_titles where tmdb_id = 5920),
    'a failed check is not retried in an hour with its error';
  assert not exists (select 1 from public.upcoming_agenda_cache where tmdb_id = 42),
    'a title off the list got an agenda row';
end $$;

select public.finish_agenda_check(27205, 'movie', null, null, 168, null);

do $$
begin
  assert not exists (select 1 from public.upcoming_agenda_cache where tmdb_id = 27205),
    'a check with nothing to show kept the agenda row';
end $$;

reset role;

-- The cron job: nothing without the Vault secret, one call with it.
update public.agenda_titles set due_at = now() - interval '1 minute';
do $$
declare
  cmd text := (select command from cron.job where jobname = 'refresh-agenda');
  before bigint := (select count(*) from net.http_request_queue);
begin
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before,
    'the cron job called out without the project_url secret';
  perform vault.create_secret('http://127.0.0.1:9', 'project_url');
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before + 1,
    'the cron job did not call refresh-agenda';
  assert (select url from net.http_request_queue order by id desc limit 1)
         = 'http://127.0.0.1:9/functions/v1/refresh-agenda',
    'the cron job called the wrong URL';
  update public.agenda_titles set due_at = now() + interval '1 hour';
  execute cmd;
  assert (select count(*) from net.http_request_queue) = before + 1,
    'the cron job called out with nothing due';
end $$;

select 'agenda_titles: ok';

rollback;
