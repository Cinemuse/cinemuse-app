-- complete_episode becomes complete_watch: the player's "finished" save
-- (updateProgress) needs the same steps, for movies too, and must do nothing
-- when the title was already finished by an earlier save.
-- No app release calls complete_episode yet, so it is dropped, not kept.
drop function if exists public.complete_episode(
  bigint, integer, integer, integer, integer, integer, boolean
);

-- Finish an episode or a movie: take it out of Continue Watching, log it and
-- move on to the next episode, in one transaction. Done as separate requests,
-- a dropped connection could leave it half done (title gone from Continue
-- Watching, or stuck "completed").
--
-- Movies use season 0 / episode 0 and no next episode.
-- The next episode needs TMDB data, so the app works it out and passes it in
-- (p_next_season / p_next_episode null = no next episode, or not known).
-- p_only_if_watching: do nothing unless this episode was still "watching".
-- The player keeps saving after the end, and only the first save may finish
-- it (later ones would log it again or reset the next episode's progress).
-- Returns the title's watch_history row after the call (no row = none left),
-- so the app can update its local cache from it.
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
  v_deleted integer;
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

  -- Only a "watching" row (REV-223): a late save used to delete the
  -- "completed" row the log trigger had just made, so a finished movie
  -- vanished from history.
  delete from public.watch_history
  where user_id = v_user_id
    and tmdb_id = p_tmdb_id
    and media_type = p_media_type
    and season = p_season
    and episode = p_episode
    and status = 'watching';
  get diagnostics v_deleted = row_count;

  if not (p_only_if_watching and v_deleted = 0) then
    -- The watch_logs trigger (sync_history_from_log) marks the title completed.
    if not exists (
      select 1
      from public.watch_logs
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type
        and season = p_season
        and episode = p_episode
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

revoke execute on function public.complete_watch(
  bigint, public.media_kind, integer, integer, integer, integer, integer,
  boolean, boolean
) from public, anon;

grant execute on function public.complete_watch(
  bigint, public.media_kind, integer, integer, integer, integer, integer,
  boolean, boolean
) to authenticated;
