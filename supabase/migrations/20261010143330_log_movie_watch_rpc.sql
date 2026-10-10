-- Mark a movie as watched (movie options: "mark as watched" / "watched
-- again") in one transaction. Before, the app inserted the log and then
-- upserted the movie's row as a second request.
--
-- p_logged_at: when it was watched (a picked date, or the app's "now", so the
-- app's not-yet-confirmed log matches the saved one).
-- p_is_now: true when no date was picked. "Now" always counts as the newest
-- watch: rows saved before REV-178 was fixed can sit 1-2 hours in the
-- future, and would otherwise keep the movie in Continue Watching.
-- Returns the movie's watch_history row after the call, so the app can
-- update its local cache from it.
create or replace function public.log_movie_watch(
  p_tmdb_id bigint,
  p_logged_at timestamptz,
  p_is_now boolean default false
)
returns setof public.watch_history
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_last_watched_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'log_movie_watch: not signed in' using errcode = '28000';
  end if;

  if p_logged_at is null then
    raise exception 'log_movie_watch: no date' using errcode = '22023';
  end if;

  -- One call at a time per user + title (same lock key as complete_watch,
  -- undo_watch and log_episodes), so the row read below can't change before
  -- the update.
  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':movie:' || p_tmdb_id::text, 0)
  );

  select wh.last_watched_at
  into v_last_watched_at
  from public.watch_history wh
  where wh.user_id = v_user_id
    and wh.tmdb_id = p_tmdb_id
    and wh.media_type = 'movie';

  -- The watch_logs trigger (sync_history_from_log) counts the watch and, for
  -- a watch at least as new as the row, sets it to "completed".
  insert into public.watch_logs
    (user_id, tmdb_id, media_type, season, episode, logged_at)
  values (v_user_id, p_tmdb_id, 'movie', 0, 0, p_logged_at);

  -- REV-179: a watch dated before the movie's last one must not move it
  -- back (the trigger already left the row alone). The newest one resets
  -- the row here too, so "now" wins over a row in the future.
  if p_is_now
    or v_last_watched_at is null
    or p_logged_at >= v_last_watched_at
  then
    update public.watch_history
    set status = 'completed',
      season = 0,
      episode = 0,
      progress_seconds = 0,
      total_duration = 0,
      last_watched_at = p_logged_at
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = 'movie';
  end if;

  return query
    select *
    from public.watch_history
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = 'movie';
end;
$$;

revoke execute on function public.log_movie_watch(
  bigint, timestamptz, boolean
) from public, anon;

grant execute on function public.log_movie_watch(
  bigint, timestamptz, boolean
) to authenticated;
