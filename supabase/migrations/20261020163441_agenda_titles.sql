-- The agenda refresh becomes a to-do list (REV-292, BE-03, BE-06).
-- Before: every change to a title called sync-agenda over HTTP (126 calls
-- for one "Mark all"), and one nightly call refreshed every title at once
-- (82 s for 571 titles, close to the edge function time limit).
-- Now: adding a title only marks it due in agenda_titles. A pg_cron job
-- every minute calls refresh-agenda when something is due; the function
-- checks up to 50 titles and says when each one is due again.
--
-- The old trigger function trigger_sync_agenda() and the sync-agenda edge
-- function stay for now: only their triggers and the nightly job go.

-- One row per followed title. Server-only, except that signed-in users'
-- triggers may add a title (it is then due at once).
CREATE TABLE public.agenda_titles (
  tmdb_id    bigint      NOT NULL,
  media_type text        NOT NULL CHECK (media_type IN ('movie', 'tv')),
  due_at     timestamptz NOT NULL DEFAULT now(),
  checked_at timestamptz,
  last_error text,
  PRIMARY KEY (tmdb_id, media_type)
);

CREATE INDEX agenda_titles_due_at_idx ON public.agenda_titles (due_at);

ALTER TABLE public.agenda_titles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.agenda_titles FROM PUBLIC, anon, authenticated;
GRANT INSERT (tmdb_id, media_type) ON public.agenda_titles TO authenticated;

CREATE POLICY "Signed-in users add titles to check" ON public.agenda_titles
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Marks a title due when it is first followed (history row, list item).
-- A title already on the list keeps its date: its data is fresh enough.
CREATE FUNCTION public.mark_agenda_title()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
BEGIN
  IF NEW.media_type IN ('movie', 'tv') THEN
    INSERT INTO public.agenda_titles (tmdb_id, media_type)
    VALUES (NEW.tmdb_id, NEW.media_type::text)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_agenda_title() FROM PUBLIC, anon, authenticated;

DROP TRIGGER on_watch_history_inserted ON public.watch_history;
DROP TRIGGER on_watch_history_changed ON public.watch_history;
DROP TRIGGER on_list_items_inserted ON public.list_items;

CREATE TRIGGER agenda_title_on_history_insert
  AFTER INSERT ON public.watch_history
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_agenda_title();

CREATE TRIGGER agenda_title_on_list_item
  AFTER INSERT ON public.list_items
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_agenda_title();

-- Called by refresh-agenda. Due titles nobody follows any more leave the
-- list with their agenda row; up to max_titles of the others are returned
-- and held for 10 minutes, so a second run doesn't take them too.
-- Followed = in someone's history or list (the app's agenda reads both).
CREATE FUNCTION public.claim_due_agenda_titles(max_titles integer)
  RETURNS TABLE (tmdb_id bigint, media_type text)
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
BEGIN
  WITH gone AS (
    DELETE FROM public.agenda_titles a
    WHERE a.due_at <= now()
      AND NOT EXISTS (
        SELECT 1 FROM public.watch_history h
        WHERE h.tmdb_id = a.tmdb_id
          AND h.media_type::text = a.media_type)
      AND NOT EXISTS (
        SELECT 1 FROM public.list_items i
        WHERE i.tmdb_id = a.tmdb_id
          AND i.media_type::text = a.media_type)
    RETURNING a.tmdb_id, a.media_type
  )
  DELETE FROM public.upcoming_agenda_cache c
  USING gone g
  WHERE c.tmdb_id = g.tmdb_id AND c.media_type = g.media_type;

  RETURN QUERY
  UPDATE public.agenda_titles a
  SET due_at = now() + interval '10 minutes'
  FROM (
    SELECT t.tmdb_id, t.media_type
    FROM public.agenda_titles t
    WHERE t.due_at <= now()
    ORDER BY t.due_at
    LIMIT max_titles
    FOR UPDATE SKIP LOCKED
  ) d
  WHERE a.tmdb_id = d.tmdb_id AND a.media_type = d.media_type
  RETURNING a.tmdb_id, a.media_type;
END;
$$;

-- Called by refresh-agenda once per checked title. With error: the title
-- is tried again in next_check_hours and its agenda row is kept. Without:
-- event_data replaces the agenda row (null removes it). A title that left
-- the list meanwhile gets no agenda row.
CREATE FUNCTION public.finish_agenda_check(
  p_tmdb_id bigint,
  p_media_type text,
  p_release_date date,
  p_event_data jsonb,
  p_next_check_hours integer,
  p_error text)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
BEGIN
  UPDATE public.agenda_titles
  SET due_at = now() + make_interval(hours => p_next_check_hours),
      checked_at = CASE WHEN p_error IS NULL THEN now() ELSE checked_at END,
      last_error = p_error
  WHERE tmdb_id = p_tmdb_id AND media_type = p_media_type;

  IF p_error IS NOT NULL OR NOT FOUND THEN
    RETURN;
  END IF;

  IF p_event_data IS NULL THEN
    DELETE FROM public.upcoming_agenda_cache
    WHERE tmdb_id = p_tmdb_id AND media_type = p_media_type;
  ELSE
    INSERT INTO public.upcoming_agenda_cache
      (tmdb_id, media_type, release_date, event_data, updated_at)
    VALUES (p_tmdb_id, p_media_type, p_release_date, p_event_data, now())
    ON CONFLICT (tmdb_id, media_type) DO UPDATE
    SET release_date = EXCLUDED.release_date,
        event_data = EXCLUDED.event_data,
        updated_at = EXCLUDED.updated_at;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_due_agenda_titles(integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.finish_agenda_check(bigint, text, date, jsonb, integer, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_agenda_titles(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_agenda_check(bigint, text, date, jsonb, integer, text) TO service_role;

-- Every followed title is due at once: the first runs work through them.
INSERT INTO public.agenda_titles (tmdb_id, media_type)
SELECT tmdb_id, media_type::text
FROM public.watch_history
WHERE media_type IN ('movie', 'tv')
UNION
SELECT tmdb_id, media_type::text
FROM public.list_items
WHERE media_type IN ('movie', 'tv')
ON CONFLICT DO NOTHING;

-- Agenda rows of titles nobody follows any more: the old function never
-- removed them.
DELETE FROM public.upcoming_agenda_cache c
WHERE NOT EXISTS (
  SELECT 1 FROM public.agenda_titles a
  WHERE a.tmdb_id = c.tmdb_id AND a.media_type = c.media_type);

-- The project URL comes from Vault (secret "project_url", set by hand on
-- production only), so a local database never calls production.
SELECT cron.unschedule('invoke-sync-agenda');

SELECT cron.schedule('refresh-agenda', '* * * * *', $cron$
  SELECT net.http_post(
    url := s.decrypted_secret || '/functions/v1/refresh-agenda',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb)
  FROM vault.decrypted_secrets s
  WHERE s.name = 'project_url'
    AND EXISTS (SELECT 1 FROM public.agenda_titles WHERE due_at <= now());
$cron$);

-- pg_cron keeps a row per run: with a job every minute, keep one week.
SELECT cron.schedule('delete-old-cron-runs', '30 3 * * *', $cron$
  DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days';
$cron$);
