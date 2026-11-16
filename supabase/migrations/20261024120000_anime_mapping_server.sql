-- The anime mapping is kept on the server (REV-338). Before: the
-- anime-mapping function downloaded Fribb's list on every call, so a broken
-- list broke every download, and only the app could pick the anime episode.
-- Now: the function keeps the worked-out list in anime_mapping, refreshed
-- once a day (the last good copy stays when the download fails), and
-- answers per episode too, with the Kitsu ids it needs cached in
-- anime_kitsu. All three tables are server-only: the function reads and
-- writes them as the service role.

-- One row per anime, in the format the app downloads (`tmdb_ranges` like
-- {"s1": "e25-e37"}).
CREATE TABLE public.anime_mapping (
  anilist_id    integer PRIMARY KEY,
  anidb_id      integer,
  tmdb_show_id  integer,
  tmdb_movie_id integer,
  tvdb_id       integer,
  tmdb_ranges   jsonb
);

CREATE INDEX anime_mapping_tmdb_show_id_idx
  ON public.anime_mapping (tmdb_show_id);
CREATE INDEX anime_mapping_tmdb_movie_id_idx
  ON public.anime_mapping (tmdb_movie_id);

-- Kitsu's id and episode count for an AniList id.
CREATE TABLE public.anime_kitsu (
  anilist_id    integer     PRIMARY KEY,
  kitsu_id      text        NOT NULL,
  episode_count integer,
  checked_at    timestamptz NOT NULL DEFAULT now()
);

-- One row: when the list was last refreshed and the last failure.
CREATE TABLE public.anime_mapping_status (
  -- Always true: the table can hold one row only.
  id           boolean PRIMARY KEY DEFAULT true CHECK (id),
  refreshed_at timestamptz,
  tried_at     timestamptz,
  row_count    integer,
  last_error   text
);

INSERT INTO public.anime_mapping_status (id) VALUES (true);

ALTER TABLE public.anime_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anime_kitsu ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anime_mapping_status ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.anime_mapping FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.anime_kitsu FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.anime_mapping_status FROM PUBLIC, anon, authenticated;

-- Called by anime-mapping with a freshly worked-out list: replaces the whole
-- list at once, so a reader never sees half of it. An AniList id twice keeps
-- its last row.
CREATE FUNCTION public.replace_anime_mapping(p_rows jsonb)
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
    (anilist_id, anidb_id, tmdb_show_id, tmdb_movie_id, tvdb_id, tmdb_ranges)
  SELECT DISTINCT ON (r.anilist_id)
    r.anilist_id, r.anidb_id, r.tmdb_show_id, r.tmdb_movie_id, r.tvdb_id,
    r.tmdb_ranges
  FROM ROWS FROM (jsonb_to_recordset(p_rows) AS (
    anilist_id integer, anidb_id integer, tmdb_show_id integer,
    tmdb_movie_id integer, tvdb_id integer, tmdb_ranges jsonb))
    WITH ORDINALITY AS r(
      anilist_id, anidb_id, tmdb_show_id, tmdb_movie_id, tvdb_id,
      tmdb_ranges, i)
  WHERE r.anilist_id IS NOT NULL
  ORDER BY r.anilist_id, r.i DESC;
  GET DIAGNOSTICS n = ROW_COUNT;

  UPDATE public.anime_mapping_status
  SET refreshed_at = now(), tried_at = now(), row_count = n, last_error = NULL
  WHERE id;
  RETURN n;
END;
$$;

-- The whole list as the app downloads it: one JSON array, without the
-- empty fields (a function, so the API's row limit doesn't cut it).
CREATE FUNCTION public.anime_mapping_rows()
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY INVOKER
  SET search_path = ''
  AS $$
  SELECT coalesce(
    jsonb_agg(jsonb_strip_nulls(to_jsonb(m)) ORDER BY m.anilist_id),
    '[]'::jsonb)
  FROM public.anime_mapping m;
$$;

REVOKE EXECUTE ON FUNCTION public.replace_anime_mapping(jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.anime_mapping_rows()
  FROM PUBLIC, anon, authenticated;

-- Every hour, anime-mapping refreshes the list when it is more than 20 hours
-- old and wasn't tried in the last hour (so a failed download is tried again
-- the next hour). Like refresh-agenda's job, it calls nothing without the
-- Vault secret project_url (production only).
SELECT cron.schedule('refresh-anime-mapping', '17 * * * *', $cron$
  SELECT net.http_post(
    url := s.decrypted_secret || '/functions/v1/anime-mapping',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 60000)
  FROM vault.decrypted_secrets s
  WHERE s.name = 'project_url'
    AND EXISTS (
      SELECT 1 FROM public.anime_mapping_status
      WHERE coalesce(refreshed_at, '-infinity') < now() - interval '20 hours'
        AND coalesce(tried_at, '-infinity') < now() - interval '1 hour');
$cron$);
