-- Two Continue Watching actions, each in one transaction. Done as separate
-- requests (read the logs, then write the row), a dropped connection or a
-- second device could leave the row half changed. Both filter by media_type
-- (REV-177: movie and TV ids overlap, the old code changed both titles).
-- Both return the title's watch_history row after the call (no row = none
-- left), so the app can update its local cache from it.

-- "Cancel rewatch": put the title back where the user was before the rewatch.
--   movie                 → "completed", progress 0
--   show, aired next      → the episode after the highest one logged becomes
--                           "watching" (the app works it out from TMDB data
--                           and passes it in)
--   show, no aired next   → the highest logged episode, "completed" (REV-180:
--                           a finished series used to stay at the rewatch
--                           episode, because nothing was written)
-- No logs = nothing to go back to, so the row is left alone. Only an existing
-- row is changed.
create or replace function public.cancel_rewatch(
  p_tmdb_id bigint,
  p_media_type public.media_kind,
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
  v_max_season integer;
  v_max_episode integer;
  v_has_next boolean :=
    p_next_aired and p_next_season is not null and p_next_episode is not null;
begin
  if v_user_id is null then
    raise exception 'cancel_rewatch: not signed in' using errcode = '28000';
  end if;

  -- One call at a time per user + title (same lock key as the other
  -- watch RPCs).
  perform pg_advisory_xact_lock(
    hashtextextended(
      v_user_id::text || ':' || p_media_type::text || ':' || p_tmdb_id::text,
      0
    )
  );

  select wl.season, wl.episode
  into v_max_season, v_max_episode
  from public.watch_logs wl
  where wl.user_id = v_user_id
    and wl.tmdb_id = p_tmdb_id
    and wl.media_type = p_media_type
  order by wl.season desc nulls last, wl.episode desc nulls last
  limit 1;

  if found then
    if p_media_type = 'movie' then
      update public.watch_history
      set status = 'completed',
          progress_seconds = 0
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type;
    else
      update public.watch_history
      set season = case when v_has_next then p_next_season else v_max_season end,
          episode = case when v_has_next then p_next_episode else v_max_episode end,
          status = case when v_has_next then 'watching' else 'completed' end,
          progress_seconds = 0,
          total_duration = 0,
          last_watched_at = now()
      where user_id = v_user_id
        and tmdb_id = p_tmdb_id
        and media_type = p_media_type;
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

revoke execute on function public.cancel_rewatch(
  bigint, public.media_kind, integer, integer, boolean
) from public, anon;

grant execute on function public.cancel_rewatch(
  bigint, public.media_kind, integer, integer, boolean
) to authenticated;

-- "Remove from Continue Watching" / clear progress.
--   no logs    → the row is deleted (the title was only started)
--   movie      → "completed", progress 0 (REV-229: the row of a movie seen
--                before was deleted, so it lost its "completed" status)
--   show       → progress 0, it stays at its current episode
create or replace function public.clear_progress(
  p_tmdb_id bigint,
  p_media_type public.media_kind
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
    raise exception 'clear_progress: not signed in' using errcode = '28000';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      v_user_id::text || ':' || p_media_type::text || ':' || p_tmdb_id::text,
      0
    )
  );

  if not exists (
    select 1
    from public.watch_logs wl
    where wl.user_id = v_user_id
      and wl.tmdb_id = p_tmdb_id
      and wl.media_type = p_media_type
  ) then
    delete from public.watch_history
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type;
  elsif p_media_type = 'movie' then
    update public.watch_history
    set status = 'completed',
        progress_seconds = 0
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type;
  else
    update public.watch_history
    set progress_seconds = 0
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type;
  end if;

  return query
    select *
    from public.watch_history
    where user_id = v_user_id
      and tmdb_id = p_tmdb_id
      and media_type = p_media_type;
end;
$$;

revoke execute on function public.clear_progress(
  bigint, public.media_kind
) from public, anon;

grant execute on function public.clear_progress(
  bigint, public.media_kind
) to authenticated;
