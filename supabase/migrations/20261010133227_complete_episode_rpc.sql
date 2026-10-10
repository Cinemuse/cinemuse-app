-- "Next episode" in the player: log the episode and move Continue Watching on,
-- in one transaction. Done as separate requests, a dropped connection could
-- leave it half done (show gone from Continue Watching, or stuck "completed").
--
-- The next episode needs TMDB data, so the app works it out and passes it in
-- (p_next_season / p_next_episode null = no next episode, or not known).
-- Returns the title's watch_history row after the change (no row = none left),
-- so the app can update its local cache from it.
create or replace function public.complete_episode(
  p_tmdb_id bigint,
  p_season integer,
  p_episode integer,
  p_duration_watched integer default null,
  p_next_season integer default null,
  p_next_episode integer default null,
  p_next_aired boolean default false
)
returns setof public.watch_history
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'complete_episode: not signed in' using errcode = '28000';
  end if;

  -- One call at a time per user + show: two saves at once could otherwise
  -- both pass the "already logged?" check and log the episode twice.
  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':tv:' || p_tmdb_id::text, 0)
  );

  delete from public.watch_history
  where user_id = v_user_id
    and tmdb_id = p_tmdb_id
    and media_type = 'tv'
    and season = p_season
    and episode = p_episode;

  -- The watch_logs trigger (sync_history_from_log) marks the title completed.
  if not exists (
    select 1
    from public.watch_logs
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = 'tv'
      and season = p_season
      and episode = p_episode
  ) then
    insert into public.watch_logs
      (user_id, tmdb_id, media_type, season, episode, logged_at, duration_watched_seconds)
    values
      (v_user_id, p_tmdb_id, 'tv', p_season, p_episode, now(), p_duration_watched);
  end if;

  -- Aired next episode → it becomes "watching". Not aired yet → the current
  -- episode stays as "completed" (caught up).
  if p_next_season is not null and p_next_episode is not null then
    insert into public.watch_history
      (user_id, tmdb_id, media_type, season, episode, status,
       progress_seconds, total_duration, last_watched_at)
    values (
      v_user_id,
      p_tmdb_id,
      'tv',
      case when p_next_aired then p_next_season else p_season end,
      case when p_next_aired then p_next_episode else p_episode end,
      case when p_next_aired then 'watching' else 'completed' end,
      0,
      0,
      now()
    )
    on conflict on constraint watch_history_pkey do update set
      season = excluded.season,
      episode = excluded.episode,
      status = excluded.status,
      progress_seconds = 0,
      total_duration = 0,
      last_watched_at = excluded.last_watched_at;
  end if;

  return query
    select *
    from public.watch_history
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = 'tv';
end;
$$;

revoke execute on function public.complete_episode(
  bigint, integer, integer, integer, integer, integer, boolean
) from public, anon;

grant execute on function public.complete_episode(
  bigint, integer, integer, integer, integer, integer, boolean
) to authenticated;
