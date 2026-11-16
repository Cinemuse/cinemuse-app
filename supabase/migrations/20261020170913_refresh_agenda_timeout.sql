-- The refresh-agenda job waited 5 s (pg_net's default) for an answer, but
-- a run takes 10-15 s, so every call was recorded as a timeout although the
-- function finished its titles (REV-325). It now waits up to 60 s.
-- cron.schedule with an existing name replaces that job.
SELECT cron.schedule('refresh-agenda', '* * * * *', $cron$
  SELECT net.http_post(
    url := s.decrypted_secret || '/functions/v1/refresh-agenda',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 60000)
  FROM vault.decrypted_secrets s
  WHERE s.name = 'project_url'
    AND EXISTS (SELECT 1 FROM public.agenda_titles WHERE due_at <= now());
$cron$);
