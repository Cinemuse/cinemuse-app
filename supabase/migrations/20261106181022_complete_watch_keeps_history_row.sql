-- A finished movie or last episode could lose its watch_history row while its
-- watch_logs stayed. complete_watch deleted the "watching" row and counted on
-- the new log's trigger to write it back as "completed". A second finish
-- within 3 hours (after jumping back during the credits, or two saves crossing)
-- logs nothing, so nothing wrote it back: no tick on the poster, and no return
-- to Continue Watching on a new episode. Only titles with no next episode were
-- hit (for the others the next-episode insert below writes the row).
-- Now the "watching" row is marked "completed" in place, so it never goes
-- away, and its watch_count is kept (deleting it restarted the count at 1).
create or replace function public.complete_watch(
  p_tmdb_id bigint,
  p_media_type public.media_kind,
  p_season integer,
  p_episode integer,
  p_duration_watched integer default null,
  p_next_season integer default null,
  p_next_episode integer default null,
  p_next_aired boolean default false,
  p_only_if_watching boolean default false
)
returns setof public.watch_history
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_finished integer;
begin
  if v_user_id is null then
    raise exception 'complete_watch: not signed in' using errcode = '28000';
  end if;

  -- One call at a time per user + title: two saves at once could otherwise
  -- both pass the "already logged?" check and log it twice.
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_user_id::text || ':' || p_media_type::text || ':' || p_tmdb_id::text,
      0
    )
  );

  -- Only a "watching" row: a "completed" or "dropped" one is left as it is.
  update public.watch_history
  set status = 'completed',
      progress_seconds = 0,
      total_duration = 0,
      last_watched_at = now()
  where user_id = v_user_id
    and tmdb_id = p_tmdb_id
    and media_type = p_media_type
    and season = p_season
    and episode = p_episode
    and status = 'watching';
  get diagnostics v_finished = row_count;

  if not (p_only_if_watching and v_finished = 0) then
    -- The watch_logs trigger (sync_history_from_log) counts the watch and
    -- marks the title completed (or writes its row, if it has none).
    if not exists (
      select 1
      from public.watch_logs
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type
        and season = p_season
        and episode = p_episode
        and logged_at > now() - interval '3 hours'
    ) then
      insert into public.watch_logs
        (user_id, tmdb_id, media_type, season, episode, logged_at,
         duration_watched_seconds)
      values
        (v_user_id, p_tmdb_id, p_media_type, p_season, p_episode, now(),
         p_duration_watched);
    end if;

    -- Aired next episode → it becomes "watching". Not aired yet → the current
    -- episode stays as "completed" (caught up).
    if p_media_type = 'tv'
      and p_next_season is not null
      and p_next_episode is not null
    then
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
  end if;

  return query
    select *
    from public.watch_history
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type;
end;
$$;

-- Put back the rows already lost: every title with watch_logs but no
-- watch_history row gets a "completed" row at its newest watch, counting all
-- its watches (the trigger's count). Whether one had been dropped is unknown.
insert into public.watch_history
  (user_id, tmdb_id, media_type, season, episode, status, progress_seconds,
   total_duration, watch_count, last_watched_at)
select distinct on (l.user_id, l.tmdb_id, l.media_type)
  l.user_id,
  l.tmdb_id,
  l.media_type,
  l.season,
  l.episode,
  'completed',
  0,
  0,
  count(*) over (partition by l.user_id, l.tmdb_id, l.media_type),
  l.logged_at
from public.watch_logs l
where not exists (
  select 1
  from public.watch_history h
  where h.user_id = l.user_id
    and h.tmdb_id = l.tmdb_id
    and h.media_type = l.media_type
)
order by l.user_id, l.tmdb_id, l.media_type,
  l.logged_at desc nulls last, l.season desc, l.episode desc;
