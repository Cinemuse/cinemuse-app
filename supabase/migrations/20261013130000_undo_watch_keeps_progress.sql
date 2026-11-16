-- DATA-05: undoing a watch must not throw away what the user is doing now.
-- When the title's newest log is removed, the row is now left alone if:
--   - it is "dropped": a title leaves Dropped only through Restore (REV-262);
--   - it is "watching" with a resume point (progress > 0): e.g. halfway
--     through a rewatch of the movie, or 20 min into the next episode
--     (user, 2026-10-13).
-- Otherwise unchanged (see 20261010140703_undo_watch_rpc.sql): no logs left →
-- the row is deleted; movie → "completed"; episode → that episode becomes
-- "watching" again.
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
    and not exists (
      select 1
      from public.watch_history
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type
        and (status = 'dropped'
          or (status = 'watching' and progress_seconds > 0))
    )
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
