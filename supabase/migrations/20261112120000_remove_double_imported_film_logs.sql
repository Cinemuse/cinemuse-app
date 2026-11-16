-- One-off cleanup: the import from the old tracking app saved every film
-- watch twice. One copy has the export's time read as world time (UTC) and
-- the film's length; the other has the same time read as Italian time, so it
-- sits 1 hour (winter) or 2 hours (summer) earlier, and has no length.
-- Each film then counted twice in the watch history and the time watched.
--
-- A film log is a copy when it has no length and the same user has another
-- log of the same film at exactly the moment this one's Italian clock time
-- names in UTC. The copy with the length stays. A lone log with no length,
-- and a real rewatch at any other time, are left alone.
--
-- The delete trigger lowers each film's watch_count by one per deleted log;
-- film rows' counts matched their logs before this cleanup.
-- Safe to run twice (the second run finds nothing).
delete from public.watch_logs wl
where wl.media_type = 'movie'
  and wl.duration_watched_seconds is null
  and exists (
    select 1
    from public.watch_logs twin
    where twin.user_id = wl.user_id
      and twin.tmdb_id = wl.tmdb_id
      and twin.media_type = wl.media_type
      and twin.season = wl.season
      and twin.episode = wl.episode
      and twin.id <> wl.id
      and twin.duration_watched_seconds is not null
      and twin.logged_at =
        ((wl.logged_at at time zone 'Europe/Rome') at time zone 'UTC')
  );
