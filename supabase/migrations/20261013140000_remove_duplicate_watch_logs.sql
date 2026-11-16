-- DATA-06, one-off cleanup: two saves at once (before complete_watch's lock)
-- could log the same episode twice, about 2 seconds apart. Those duplicates
-- inflate the stats (user_stats counts watch_logs) and watch_count.
-- A log is a duplicate when the same user logged the same title / season /
-- episode less than a minute after the previous log of it; the earliest one
-- is kept. Safe to run twice (the second run finds nothing).
delete from public.watch_logs wl
using (
  select
    id,
    logged_at - lag(logged_at) over (
      partition by user_id, tmdb_id, media_type, season, episode
      order by logged_at, id
    ) as since_previous
  from public.watch_logs
  where logged_at is not null
) d
where wl.id = d.id
  and d.since_previous < interval '1 minute';

-- The delete trigger only lowers watch_count when the row points at the
-- deleted episode, so count it again: one per log of the title, as the
-- insert trigger adds.
update public.watch_history wh
set watch_count = (
  select count(*)
  from public.watch_logs wl
  where wl.user_id = wh.user_id
    and wl.tmdb_id = wh.tmdb_id
    and wl.media_type = wh.media_type
)
where wh.watch_count is distinct from (
  select count(*)
  from public.watch_logs wl
  where wl.user_id = wh.user_id
    and wl.tmdb_id = wh.tmdb_id
    and wl.media_type = wh.media_type
);
