-- Mark one or more episodes of a show as watched (episode list: one tick,
-- "watched again", mark season / all) and move Continue Watching on, in one
-- transaction. Done as separate requests, a dropped connection could leave
-- the episodes logged but the show stuck or gone from Continue Watching.
--
-- p_episodes: json array of {"season": n, "episode": n}, all logged at
-- p_logged_at (null = now).
-- The next episode needs TMDB data, so the app works it out from the
-- highest episode in the list and passes it in (p_next_season /
-- p_next_episode null = no next episode, or not known).
-- Returns the show's watch_history row after the call, so the app can update
-- its local cache from it.
create or replace function public.log_episodes(
  p_tmdb_id bigint,
  p_episodes jsonb,
  p_logged_at timestamptz default null,
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
  v_logged_at timestamptz := coalesce(p_logged_at, now());
  v_last_watched_at timestamptz;
  v_latest_season integer;
  v_latest_episode integer;
  v_has_next boolean :=
    p_next_aired and p_next_season is not null and p_next_episode is not null;
begin
  if v_user_id is null then
    raise exception 'log_episodes: not signed in' using errcode = '28000';
  end if;

  if jsonb_typeof(p_episodes) is distinct from 'array'
    or jsonb_array_length(p_episodes) = 0
    or exists (
      select 1
      from jsonb_to_recordset(p_episodes) as e(season integer, episode integer)
      where e.season is null or e.episode is null
    )
  then
    raise exception 'log_episodes: no valid episodes' using errcode = '22023';
  end if;

  -- One call at a time per user + title (same lock key as complete_watch and
  -- undo_watch), so the row read below can't change before the update.
  perform pg_advisory_xact_lock(
    hashtextextended(v_user_id::text || ':tv:' || p_tmdb_id::text, 0)
  );

  select wh.last_watched_at
  into v_last_watched_at
  from public.watch_history wh
  where wh.user_id = v_user_id
    and wh.tmdb_id = p_tmdb_id
    and wh.media_type = 'tv';

  -- The watch_logs trigger (sync_history_from_log) counts each watch.
  insert into public.watch_logs
    (user_id, tmdb_id, media_type, season, episode, logged_at)
  select v_user_id, p_tmdb_id, 'tv', e.season, e.episode, v_logged_at
  from jsonb_to_recordset(p_episodes) as e(season integer, episode integer)
  order by e.season, e.episode;

  -- REV-179: a watch dated before the show's last one must not move it back.
  -- "Now" always counts as newest: rows saved before REV-178 was fixed can
  -- sit 1-2 hours in the future, and would otherwise block it.
  if p_logged_at is null
    or v_last_watched_at is null
    or p_logged_at >= v_last_watched_at
  then
    select e.season, e.episode
    into v_latest_season, v_latest_episode
    from jsonb_to_recordset(p_episodes) as e(season integer, episode integer)
    order by e.season desc, e.episode desc
    limit 1;

    -- Aired next episode → it becomes "watching". Otherwise (not aired yet,
    -- or none) the highest marked episode stays as "completed".
    insert into public.watch_history
      (user_id, tmdb_id, media_type, season, episode, status,
       progress_seconds, total_duration, last_watched_at)
    values (
      v_user_id,
      p_tmdb_id,
      'tv',
      case when v_has_next then p_next_season else v_latest_season end,
      case when v_has_next then p_next_episode else v_latest_episode end,
      case when v_has_next then 'watching' else 'completed' end,
      0,
      0,
      v_logged_at
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

revoke execute on function public.log_episodes(
  bigint, jsonb, timestamptz, integer, integer, boolean
) from public, anon;

grant execute on function public.log_episodes(
  bigint, jsonb, timestamptz, integer, integer, boolean
) to authenticated;
