-- The anime list is built from two lists: AniBridge's exact TMDB episodes
-- and Fribb's numbers. Each line now holds the anime's Kitsu id, its exact
-- TMDB episodes and which list placed them; the refresh note keeps each
-- list's size, so a list that shrinks by more than a tenth is refused.
-- Kitsu is no longer asked at play time, so its cache goes (it was never
-- filled). `tmdb_ranges` stays until the app reads `tmdb_episodes`.

-- The anime's TMDB episodes, e.g.
-- [{"season": 1, "first": 25, "last": 37, "anime_first": 1}]
-- (TMDB S1 E25-E37 = the anime's episodes 1-13; no "last": open at the end).
ALTER TABLE public.anime_mapping
  ADD COLUMN kitsu_id      integer,
  ADD COLUMN tmdb_episodes jsonb,
  ADD COLUMN placed_by     text
    CHECK (placed_by IN ('anibridge', 'fribb', 'fix'));

-- How many anime each list had at the last good refresh.
ALTER TABLE public.anime_mapping_status
  ADD COLUMN anibridge_count integer,
  ADD COLUMN fribb_count     integer;

DROP TABLE public.anime_kitsu;

DROP FUNCTION public.replace_anime_mapping(jsonb);

-- Called by anime-mapping with a freshly built list: replaces the whole list
-- at once, so a reader never sees half of it. An AniList id twice keeps its
-- last line.
CREATE FUNCTION public.replace_anime_mapping(
  p_rows jsonb,
  p_anibridge_count integer,
  p_fribb_count integer)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
DECLARE
  n integer;
BEGIN
  DELETE FROM public.anime_mapping WHERE true;

  INSERT INTO public.anime_mapping
    (anilist_id, anidb_id, kitsu_id, tmdb_show_id, tmdb_movie_id, tvdb_id,
     tmdb_episodes, placed_by, tmdb_ranges)
  SELECT DISTINCT ON (r.anilist_id)
    r.anilist_id, r.anidb_id, r.kitsu_id, r.tmdb_show_id, r.tmdb_movie_id,
    r.tvdb_id, r.tmdb_episodes, r.placed_by, r.tmdb_ranges
  FROM ROWS FROM (jsonb_to_recordset(p_rows) AS (
    anilist_id integer, anidb_id integer, kitsu_id integer,
    tmdb_show_id integer, tmdb_movie_id integer, tvdb_id integer,
    tmdb_episodes jsonb, placed_by text, tmdb_ranges jsonb))
    WITH ORDINALITY AS r(
      anilist_id, anidb_id, kitsu_id, tmdb_show_id, tmdb_movie_id, tvdb_id,
      tmdb_episodes, placed_by, tmdb_ranges, i)
  WHERE r.anilist_id IS NOT NULL
  ORDER BY r.anilist_id, r.i DESC;
  GET DIAGNOSTICS n = ROW_COUNT;

  UPDATE public.anime_mapping_status
  SET refreshed_at = now(), tried_at = now(), row_count = n, last_error = NULL,
      anibridge_count = p_anibridge_count, fribb_count = p_fribb_count
  WHERE id;
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.replace_anime_mapping(jsonb, integer, integer)
  FROM PUBLIC, anon, authenticated;

-- Rebuild the list from both lists at the next hourly run.
UPDATE public.anime_mapping_status SET refreshed_at = NULL WHERE id;
