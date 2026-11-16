-- REV-361: the default playlist and its guide are two files in the public
-- Storage bucket livetv (playlist.m3u, epg.json), written by the live-tv
-- function; the channels and every address are in its code, and epg.json
-- itself remembers each guide source's last read. The tables, functions and
-- 5-minute job of 20261024150000_live_tv.sql go.

SELECT cron.unschedule('refresh-tv-guide');

DROP FUNCTION public.save_tv_guide_source(text, jsonb, text);
DROP FUNCTION public.build_tv_guide();
DROP FUNCTION public.claim_tv_guide_source();

DROP TABLE public.tv_guide_status, public.tv_guide, public.tv_guide_programmes,
  public.tv_guide_sources, public.tv_channels, public.tv_link_services;

-- Every hour live-tv writes the playlist if the channel list changed and
-- reads the guide source most overdue, if any (one per call: each is read
-- about once a day). Like the other jobs, it calls nothing without the Vault
-- secret project_url (production only).
SELECT cron.schedule('refresh-live-tv', '41 * * * *', $cron$
  SELECT net.http_post(
    url := s.decrypted_secret || '/functions/v1/live-tv',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 150000)
  FROM vault.decrypted_secrets s
  WHERE s.name = 'project_url';
$cron$);
