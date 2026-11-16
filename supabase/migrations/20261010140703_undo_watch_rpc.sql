-- Undo a watch (remove logs) and fix up the title's watch_history row in one
-- transaction. Done as separate requests (delete logs, delete the row, insert
-- a new row), a dropped connection could leave the title gone from Continue
-- Watching.
--
-- p_season / p_episode null = every log of the title (whole movie or series).
-- p_only_latest: remove only the newest matching log ("remove one" button).
--
-- The row only changes when the title's newest log was removed (REV-225:
-- undoing an old log used to reset Continue Watching and its progress):
--   no logs left       → the row is deleted
--   movie              → stays "completed", dated by its newest log left
--                        (REV-224: it became "watching", so it showed up in
--                        Continue Watching)
--   episode            → that episode becomes "watching" again (the one the
--                        user still has to see), dated by the newest log left
-- Returns the title's watch_history row after the call (no row = none left),
-- so the app can update its local cache from it.
create or replace function public.undo_watch(
  p_tmdb_id bigint,
  p_media_type public.media_kind,
  p_season integer default null,
  p_episode integer default null,
  p_only_latest boolean default false
)
returns setof public.watch_history
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_newest_id uuid;
  v_deleted integer;
  v_left record;
begin
  if v_user_id is null then
    raise exception 'undo_watch: not signed in' using errcode = '28000';
  end if;

  -- Same lock as complete_watch: one change at a time per user + title.
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_user_id::text || ':' || p_media_type::text || ':' || p_tmdb_id::text,
      0
    )
  );

  -- "Newest" breaks ties by episode: marking a whole season logs every
  -- episode with the same time.
  select id into v_newest_id
  from public.watch_logs
  where user_id = v_user_id
    and tmdb_id = p_tmdb_id
    and media_type = p_media_type
  order by logged_at desc nulls last, season desc, episode desc
  limit 1;

  delete from public.watch_logs
  where id in (
    select id
    from public.watch_logs
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type
      and (p_season is null or (season = p_season and episode = p_episode))
    order by logged_at desc nulls last
    -- limit null = no limit
    limit case when p_only_latest then 1 end
  );
  get diagnostics v_deleted = row_count;

  if v_deleted > 0
    and not exists (select 1 from public.watch_logs where id = v_newest_id)
  then
    select season, episode, logged_at into v_left
    from public.watch_logs
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type
    order by logged_at desc nulls last, season desc, episode desc
    limit 1;

    if not found then
      delete from public.watch_history
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type;
    else
      insert into public.watch_history
        (user_id, tmdb_id, media_type, season, episode, status,
         progress_seconds, total_duration, last_watched_at)
      values (
        v_user_id,
        p_tmdb_id,
        p_media_type,
        -- Whole series removed with logs left can't happen (all are gone);
        -- the newest log left is only a fallback.
        coalesce(p_season, v_left.season),
        coalesce(p_episode, v_left.episode),
        case when p_media_type = 'movie' then 'completed' else 'watching' end,
        0,
        0,
        v_left.logged_at
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

revoke execute on function public.undo_watch(
  bigint, public.media_kind, integer, integer, boolean
) from public, anon;

grant execute on function public.undo_watch(
  bigint, public.media_kind, integer, integer, boolean
) to authenticated;

-- REV-179: a log with an older date (logged after the fact) must not move the
-- title back. Before, it always set "completed" and its old date, so a show
-- being watched left Continue Watching and sorted as last year. Now only a
-- log at least as new as the row moves status, date and episode; the watch
-- count still goes up.
create or replace function public.sync_history_from_log()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.watch_history as wh
      (user_id, tmdb_id, media_type, season, episode, status, watch_count,
       last_watched_at)
    values
      (new.user_id, new.tmdb_id, new.media_type, new.season, new.episode,
       'completed', 1, new.logged_at)
    on conflict on constraint watch_history_pkey do update set
      watch_count = wh.watch_count + 1,
      status = case when wh.last_watched_at is null
          or new.logged_at >= wh.last_watched_at
        then 'completed' else wh.status end,
      season = case when wh.last_watched_at is null
          or new.logged_at >= wh.last_watched_at
        then new.season else wh.season end,
      episode = case when wh.last_watched_at is null
          or new.logged_at >= wh.last_watched_at
        then new.episode else wh.episode end,
      progress_seconds = case when wh.last_watched_at is null
          or new.logged_at >= wh.last_watched_at
        then 0 else wh.progress_seconds end,
      -- greatest() skips nulls.
      last_watched_at = greatest(wh.last_watched_at, new.logged_at);
  end if;

  if tg_op = 'DELETE' then
    update public.watch_history
    set watch_count = greatest(0, watch_count - 1)
    where user_id = old.user_id
      and tmdb_id = old.tmdb_id
      and media_type = old.media_type
      and season = old.season
      and episode = old.episode;
  end if;

  return null;
end;
$$;
