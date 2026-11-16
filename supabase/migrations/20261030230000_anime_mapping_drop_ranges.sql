-- The app reads each anime's exact TMDB episodes (`tmdb_episodes`), so the
-- old `{"s1": "e25-e37"}` column goes. anime-mapping no longer writes or
-- reads it (deploy it before this migration).

-- Same as before, without `tmdb_ranges`. CREATE OR REPLACE keeps its grants.
CREATE OR REPLACE FUNCTION public.replace_anime_mapping(
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
     tmdb_episodes, placed_by)
  SELECT DISTINCT ON (r.anilist_id)
    r.anilist_id, r.anidb_id, r.kitsu_id, r.tmdb_show_id, r.tmdb_movie_id,
    r.tvdb_id, r.tmdb_episodes, r.placed_by
  FROM ROWS FROM (jsonb_to_recordset(p_rows) AS (
    anilist_id integer, anidb_id integer, kitsu_id integer,
    tmdb_show_id integer, tmdb_movie_id integer, tvdb_id integer,
    tmdb_episodes jsonb, placed_by text))
    WITH ORDINALITY AS r(
      anilist_id, anidb_id, kitsu_id, tmdb_show_id, tmdb_movie_id, tvdb_id,
      tmdb_episodes, placed_by, i)
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

ALTER TABLE public.anime_mapping DROP COLUMN tmdb_ranges;
