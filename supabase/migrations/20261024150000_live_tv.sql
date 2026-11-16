-- The default "Cinemuse IPTV" playlist and its TV guide (REV-336, REV-386,
-- REV-126). The live-tv function serves both from these tables:
--   tv_channels       one row per channel: name, number, logo, how it plays,
--                     its guide sources in order (edited in the Supabase
--                     website, like scraper_sites)
--   tv_link_services  how a stream address is built from a channel's id
--                     (Rai's and Sky's "ask" services, Mediaset, Discovery)
--   tv_guide_sources  the guide sources: address, how often, last error
--   tv_guide_programmes  each source's last good copy, per source channel
--   tv_guide          the built guide, as served (epg.json)
--   tv_guide_status   per channel: which source the guide uses, how far ahead
-- All server-only: the function reads and writes them as the service role.

CREATE TABLE public.tv_link_services (
  key     text PRIMARY KEY CHECK (key ~ '^[a-z0-9_]+$'),
  -- The stream address, `{id}` replaced by the channel's `stream`.
  address text NOT NULL CHECK (address ~ '^https://\S+$' AND address LIKE '%{id}%'),
  -- True: the address answers with the real stream address, valid a few
  -- minutes, and only to Italian devices, so the device asks it at play time.
  ask     boolean NOT NULL DEFAULT false,
  note    text NOT NULL DEFAULT ''
);

CREATE TABLE public.tv_channels (
  -- The channel's id in the playlist and the guide (`tvg-id`): never rename
  -- one, apps match the guide on it.
  key           text PRIMARY KEY CHECK (key ~ '^[a-z0-9_]+$' AND key <> 'channels'),
  name          text NOT NULL,
  -- The channel number (LCN); empty when it has none.
  lcn           integer CHECK (lcn > 0),
  category      text NOT NULL DEFAULT '',
  -- A file of the channel-logos bucket, or a full https address.
  logo          text NOT NULL DEFAULT '',
  -- How `stream` becomes the address: a tv_link_services key, or empty when
  -- `stream` is the address itself.
  link_service  text REFERENCES public.tv_link_services (key) ON UPDATE CASCADE,
  stream        text,
  -- False: the channel is only in the guide (no stream, or turned off).
  in_playlist   boolean NOT NULL DEFAULT true,
  -- In order, the first that covers the next 48 hours wins:
  -- [{"source": "rai", "id": "rai-1"}, {"source": "sky", "id": "6601", "env": "DTT"}, ...]
  guide_sources jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(guide_sources) = 'array'),
  note          text NOT NULL DEFAULT '',
  CHECK (NOT in_playlist OR stream IS NOT NULL)
);

CREATE TABLE public.tv_guide_sources (
  key           text PRIMARY KEY CHECK (key ~ '^[a-z0-9_]+$'),
  -- Which reader of the live-tv function understands it.
  reader        text NOT NULL CHECK (reader IN ('rai', 'mediaset', 'sky', 'discovery', 'xmltv')),
  -- The address; `{id}`, `{date}`, `{from}`, `{to}`, `{env}`, `{page}` are
  -- filled by the reader (docs/backend.md -> live-tv).
  address       text NOT NULL CHECK (address ~ '^https://\S+$'),
  refresh_hours integer NOT NULL DEFAULT 12 CHECK (refresh_hours BETWEEN 1 AND 168),
  refreshed_at  timestamptz,
  tried_at      timestamptz,
  -- The last refresh's error; on a refresh that saved programmes, the
  -- channels it couldn't read.
  last_error    text,
  note          text NOT NULL DEFAULT ''
);

CREATE TABLE public.tv_guide_programmes (
  source      text NOT NULL REFERENCES public.tv_guide_sources (key)
                ON UPDATE CASCADE ON DELETE CASCADE,
  -- The source's own channel id (`id` in tv_channels.guide_sources).
  ref         text NOT NULL,
  starts_at   timestamptz NOT NULL,
  ends_at     timestamptz NOT NULL CHECK (ends_at > starts_at),
  title       text NOT NULL,
  subtitle    text,
  description text,
  image       text,
  PRIMARY KEY (source, ref, starts_at)
);

-- One row: the guide as served.
CREATE TABLE public.tv_guide (
  -- Always true: the table can hold one row only.
  id       boolean PRIMARY KEY DEFAULT true CHECK (id),
  built_at timestamptz NOT NULL,
  body     text NOT NULL
);

CREATE TABLE public.tv_guide_status (
  channel     text PRIMARY KEY REFERENCES public.tv_channels (key)
                ON UPDATE CASCADE ON DELETE CASCADE,
  -- Null: no source has a guide for it.
  source      text,
  -- 1 = its first source.
  source_rank integer,
  -- The end of its last programme.
  ends_at     timestamptz,
  -- Since when it uses this source.
  since       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tv_link_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_guide_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_guide_programmes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_guide ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_guide_status ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.tv_link_services FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tv_channels FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tv_guide_sources FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tv_guide_programmes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tv_guide FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tv_guide_status FROM PUBLIC, anon, authenticated;

-- Takes the source most overdue for a refresh and marks it tried, so two
-- runs never read the same source. Due: not refreshed for `refresh_hours`
-- and not tried in the last hour (a failed source is tried again hourly).
CREATE FUNCTION public.claim_tv_guide_source()
  RETURNS SETOF public.tv_guide_sources
  LANGUAGE sql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
  UPDATE public.tv_guide_sources s
  SET tried_at = now()
  WHERE s.key = (
    SELECT d.key FROM public.tv_guide_sources d
    WHERE coalesce(d.refreshed_at, '-infinity') < now() - make_interval(hours => d.refresh_hours)
      AND coalesce(d.tried_at, '-infinity') < now() - interval '1 hour'
    ORDER BY d.refreshed_at NULLS FIRST, d.key
    LIMIT 1
    FOR UPDATE SKIP LOCKED)
  RETURNING s.*;
$$;

-- Works out each channel's source and writes the served guide and the
-- status. The rule: the first source (in the channel's order) whose copy
-- covers now and reaches 48 hours ahead; if none, the one reaching
-- furthest. A copy made mostly of one-hour blocks on the hour is a
-- placeholder, never used. The whole channel comes from one source.
-- The guide: a map channel key -> programmes (from a day ago to 8 days
-- ahead, the format apps already read), plus "channels": each key's name
-- and number (older apps skip it: it isn't a list).
CREATE FUNCTION public.build_tv_guide()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
BEGIN
  CREATE TEMP TABLE chosen ON COMMIT DROP AS
  WITH stats AS (
    SELECT p.source, p.ref,
      max(p.ends_at) AS reach,
      bool_or(p.starts_at <= now() AND p.ends_at > now()) AS covers_now,
      avg((p.ends_at - p.starts_at = interval '1 hour'
        AND date_trunc('hour', p.starts_at) = p.starts_at)::int) > 0.8 AS placeholder
    FROM public.tv_guide_programmes p
    WHERE p.ends_at > now()
    GROUP BY p.source, p.ref
  ), candidates AS (
    SELECT c.key, e.src ->> 'source' AS source, e.src ->> 'id' AS ref,
      e.rank::integer AS rank, st.reach,
      st.covers_now AND st.reach >= now() + interval '48 hours' AS good
    FROM public.tv_channels c
    CROSS JOIN LATERAL jsonb_array_elements(c.guide_sources)
      WITH ORDINALITY AS e(src, rank)
    JOIN stats st ON st.source = e.src ->> 'source' AND st.ref = e.src ->> 'id'
    WHERE NOT st.placeholder
  )
  SELECT DISTINCT ON (key) key, source, ref, rank, reach
  FROM candidates
  ORDER BY key, good DESC, CASE WHEN good THEN rank END, reach DESC, rank;

  INSERT INTO public.tv_guide (id, built_at, body)
  SELECT true, now(), (
    coalesce((
      SELECT jsonb_object_agg(ch.key, (
        SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
            'name', p.title,
            'subtitle', p.subtitle,
            'description', p.description,
            'startTime', jsonb_build_object('unix', (extract(epoch FROM p.starts_at) * 1000)::bigint),
            'endTime', jsonb_build_object('unix', (extract(epoch FROM p.ends_at) * 1000)::bigint),
            'image', p.image))
          ORDER BY p.starts_at)
        FROM public.tv_guide_programmes p
        WHERE p.source = ch.source AND p.ref = ch.ref
          AND p.ends_at > now() - interval '1 day'
          AND p.starts_at < now() + interval '8 days'))
      FROM chosen ch), '{}'::jsonb)
    || jsonb_build_object('channels', coalesce((
      SELECT jsonb_object_agg(c.key, jsonb_strip_nulls(
        jsonb_build_object('name', c.name, 'lcn', c.lcn)))
      FROM public.tv_channels c), '{}'::jsonb))
  )::text
  ON CONFLICT (id) DO UPDATE SET built_at = excluded.built_at, body = excluded.body;

  DELETE FROM public.tv_guide_status s
  WHERE NOT EXISTS (SELECT 1 FROM public.tv_channels c WHERE c.key = s.channel);

  INSERT INTO public.tv_guide_status AS s (channel, source, source_rank, ends_at, since)
  SELECT c.key, ch.source, ch.rank, ch.reach, now()
  FROM public.tv_channels c
  LEFT JOIN chosen ch ON ch.key = c.key
  ON CONFLICT (channel) DO UPDATE SET
    source = excluded.source,
    source_rank = excluded.source_rank,
    ends_at = excluded.ends_at,
    since = CASE WHEN s.source IS NOT DISTINCT FROM excluded.source
      THEN s.since ELSE now() END;

  DROP TABLE chosen;
END;
$$;

-- Saves what a source answered and rebuilds the guide. `p_rows`:
-- [{"ref", "start", "stop", "title", "subtitle", "description", "image"}]
-- (times as ISO strings). For each channel in it, the new copy replaces the
-- old from its first programme on; channels missing from it keep their old
-- copy. `p_error`: the channels it couldn't read (null when none). No rows:
-- a failed refresh, only the error is saved. Programmes that ended more
-- than a day ago are deleted.
CREATE FUNCTION public.save_tv_guide_source(p_source text, p_rows jsonb, p_error text)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY INVOKER
  SET search_path = ''
  AS $$
DECLARE
  n integer;
BEGIN
  IF coalesce(jsonb_array_length(p_rows), 0) = 0 THEN
    UPDATE public.tv_guide_sources
    SET tried_at = now(), last_error = coalesce(p_error, 'No programmes')
    WHERE key = p_source;
    RETURN 0;
  END IF;

  CREATE TEMP TABLE incoming ON COMMIT DROP AS
  SELECT DISTINCT ON (r.ref, r.start)
    r.ref, r.start, r.stop, r.title, r.subtitle, r.description, r.image
  FROM jsonb_to_recordset(p_rows) AS r(
    ref text, start timestamptz, stop timestamptz, title text,
    subtitle text, description text, image text)
  WHERE r.ref IS NOT NULL AND r.title IS NOT NULL AND r.title <> ''
    AND r.stop > r.start
  ORDER BY r.ref, r.start, r.stop DESC;

  DELETE FROM public.tv_guide_programmes p
  USING (SELECT ref, min(start) AS first_start FROM incoming GROUP BY ref) f
  WHERE p.source = p_source AND p.ref = f.ref AND p.ends_at > f.first_start;

  INSERT INTO public.tv_guide_programmes
    (source, ref, starts_at, ends_at, title, subtitle, description, image)
  SELECT p_source, i.ref, i.start, i.stop, i.title,
    nullif(i.subtitle, ''), nullif(i.description, ''), nullif(i.image, '')
  FROM incoming i;
  GET DIAGNOSTICS n = ROW_COUNT;

  DELETE FROM public.tv_guide_programmes WHERE ends_at < now() - interval '1 day';

  UPDATE public.tv_guide_sources
  SET refreshed_at = now(), tried_at = now(), last_error = p_error
  WHERE key = p_source;

  DROP TABLE incoming;
  PERFORM public.build_tv_guide();
  RETURN n;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_tv_guide_source() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.build_tv_guide() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.save_tv_guide_source(text, jsonb, text) FROM PUBLIC, anon, authenticated;

-- Every 5 minutes, when a guide source is due, live-tv refreshes it (one
-- source per call). Like the other jobs, it calls nothing without the Vault
-- secret project_url (production only).
SELECT cron.schedule('refresh-tv-guide', '*/5 * * * *', $cron$
  SELECT net.http_post(
    url := s.decrypted_secret || '/functions/v1/live-tv',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 150000)
  FROM vault.decrypted_secrets s
  WHERE s.name = 'project_url'
    AND EXISTS (
      SELECT 1 FROM public.tv_guide_sources d
      WHERE coalesce(d.refreshed_at, '-infinity') < now() - make_interval(hours => d.refresh_hours)
        AND coalesce(d.tried_at, '-infinity') < now() - interval '1 hour');
$cron$);

-- First content (research/free-to-air-channels.md, research/tv-guide.md):
-- edited in the Supabase website from now on.

INSERT INTO public.tv_link_services (key, address, ask, note) VALUES
  ('rai', 'https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont={id}&output=63&forceUserAgent=raiplayappletv',
    true, 'Rai: answers JSON, the stream address in video[0]'),
  ('sky', 'https://video.sky.it/api/v1/getLivestream?id={id}&isMobile=false',
    true, 'Sky (TV8, Cielo, Sky TG24): answers JSON, the stream address in streaming_url'),
  ('mediaset', 'https://live02-seg.msf.cdn.mediaset.net/live/ch-{id}/{id}-clr.isml/index.m3u8',
    false, 'Mediaset TV channels, by call sign'),
  ('mediaset_radio', 'https://live02-seg.msr.cdn.mediaset.net/live/ch-{id}/{id}-clr.isml/index.m3u8',
    false, 'Mediaset radio channels, by call sign'),
  ('discovery', 'https://streaming.aurora.enhanced.live/live/mpc/enl0eG1mLmVncmVzcy5mZDJ2eHI=/out/v1/IT_SIMULCAST/{id}/CMAF/index.m3u8',
    false, 'Warner Bros. Discovery Italy channels, by name');

INSERT INTO public.tv_guide_sources (key, reader, address, refresh_hours, note) VALUES
  ('rai', 'rai', 'https://www.raiplay.it/palinsesto/app/{id}/{date}.json', 12,
    'RaiPlay: one channel, one day ({date} = DD-MM-YYYY); 7 days'),
  ('mediaset', 'mediaset', 'https://api-ott-prod-fe.mediaset.net/PROD/play/feed/allListingFeedEpg/v2.0?byListingTime={from}~{to}&byCallSign={id}', 12,
    'Mediaset: one channel, at most 39 hours per call ({from}, {to} in ms)'),
  ('sky', 'sky', 'https://apid.sky.it/gtv/v1/events?from={from}&to={to}&env={env}&channels={id}&pageSize=500&pageNum={page}', 12,
    'Sky guide: one channel per call ({env} DTT or DTH, the list it is in)'),
  ('discovery', 'discovery', 'https://public.aurora.enhanced.live/site/page/guida-tv/?include=default&filter[environment]={id}', 12,
    'Warner Bros. Discovery Italy sites: one channel, 7 days'),
  ('iptv_epg', 'xmltv', 'https://iptv-epg.org/files/epg-it.xml.gz', 6,
    'iptv-epg.org community feed (XMLTV)'),
  ('open_epg_3', 'xmltv', 'https://www.open-epg.com/files/italy3.xml.gz', 6,
    'open-epg community feed (XMLTV), ~2 days'),
  ('open_epg_8', 'xmltv', 'https://www.open-epg.com/files/italy8.xml.gz', 6,
    'open-epg community feed (XMLTV), ~2 days');

INSERT INTO public.tv_channels
  (key, name, lcn, category, logo, link_service, stream, in_playlist, guide_sources) VALUES
  ('rai1', 'Rai 1', 1, 'Nazionali', 'rai1.png', 'rai', '2606803', true,
    '[{"source":"rai","id":"rai-1"},{"source":"sky","id":"6601","env":"DTT"},{"source":"iptv_epg","id":"Rai1.it"},{"source":"open_epg_3","id":"Rai 1.it"}]'),
  ('rai2', 'Rai 2', 2, 'Nazionali', 'rai2.png', 'rai', '308718', true,
    '[{"source":"rai","id":"rai-2"},{"source":"sky","id":"6621","env":"DTT"},{"source":"iptv_epg","id":"Rai2.it"},{"source":"open_epg_3","id":"Rai 2.it"}]'),
  ('rai3', 'Rai 3', 3, 'Nazionali', 'rai3.png', 'rai', '308709', true,
    '[{"source":"rai","id":"rai-3"},{"source":"sky","id":"6602","env":"DTT"},{"source":"iptv_epg","id":"Rai3.it"},{"source":"open_epg_3","id":"Rai 3.it"}]'),
  ('r4', 'Rete 4', 4, 'Nazionali', 'rete4.png', 'mediaset', 'r4', true,
    '[{"source":"mediaset","id":"R4"},{"source":"sky","id":"10464","env":"DTH"},{"source":"iptv_epg","id":"Rete4.it"},{"source":"open_epg_3","id":"Rete 4.it"}]'),
  ('c5', 'Canale 5', 5, 'Nazionali', 'canale5.png', 'mediaset', 'c5', true,
    '[{"source":"mediaset","id":"C5"},{"source":"sky","id":"10354","env":"DTH"},{"source":"iptv_epg","id":"Canale5.it"},{"source":"open_epg_3","id":"Canale 5.it"}]'),
  ('i1', 'Italia 1', 6, 'Nazionali', 'italia1.png', 'mediaset', 'i1', true,
    '[{"source":"mediaset","id":"I1"},{"source":"sky","id":"10454","env":"DTH"},{"source":"iptv_epg","id":"Italia1.it"},{"source":"open_epg_3","id":"Italia 1.it"}]'),
  ('la7', 'La7', 7, 'Nazionali', 'la7.png', NULL, 'https://d3k8wzt41aflvx.cloudfront.net/LA7HD/Live.m3u8', true,
    '[{"source":"sky","id":"8329","env":"DTT"},{"source":"iptv_epg","id":"La7.it"},{"source":"open_epg_3","id":"La7.it"}]'),
  ('tv8', 'TV8', 8, 'Nazionali', 'tv8.png', 'sky', '7', true,
    '[{"source":"sky","id":"8327","env":"DTT"},{"source":"iptv_epg","id":"TV8.it"},{"source":"open_epg_3","id":"TV8.it"}]'),
  ('nove', 'Nove', 9, 'Nazionali', 'nove.png', 'discovery', 'NOVE', true,
    '[{"source":"discovery","id":"nove"},{"source":"sky","id":"12115","env":"DTT"},{"source":"iptv_epg","id":"NOVE.it"},{"source":"open_epg_3","id":"Nove.it"}]'),
  ('c20', '20 Mediaset', 20, 'Nazionali', '20.png', 'mediaset', 'lb', true,
    '[{"source":"mediaset","id":"LB"},{"source":"sky","id":"10458","env":"DTH"},{"source":"iptv_epg","id":"Mediaset20.it"},{"source":"open_epg_3","id":"20.it"}]'),
  ('rai4', 'Rai 4', 21, 'Nazionali', 'rai4.png', 'rai', '746966', true,
    '[{"source":"rai","id":"rai-4"},{"source":"sky","id":"6622","env":"DTT"},{"source":"iptv_epg","id":"Rai4.it"},{"source":"open_epg_3","id":"Rai 4.it"}]'),
  ('iris', 'Iris', 22, 'Cinema', 'iris.png', 'mediaset', 'ki', true,
    '[{"source":"mediaset","id":"KI"},{"source":"sky","id":"10467","env":"DTH"},{"source":"iptv_epg","id":"Iris.it"},{"source":"open_epg_3","id":"Iris.it"}]'),
  ('rai5', 'Rai 5', 23, 'Nazionali', 'rai5.png', 'rai', '395276', true,
    '[{"source":"rai","id":"rai-5"},{"source":"sky","id":"6607","env":"DTT"},{"source":"iptv_epg","id":"Rai5.it"},{"source":"open_epg_3","id":"Rai 5.it"}]'),
  ('raimovie', 'Rai Movie', 24, 'Cinema', 'raimovie.png', 'rai', '747002', true,
    '[{"source":"rai","id":"rai-movie"},{"source":"sky","id":"6608","env":"DTT"},{"source":"iptv_epg","id":"RaiMovie.it"},{"source":"open_epg_3","id":"Rai Movie.it"}]'),
  ('raipremium', 'Rai Premium', 25, 'Cinema', 'raipremium.png', 'rai', '746992', true,
    '[{"source":"rai","id":"rai-premium"},{"source":"sky","id":"6623","env":"DTT"},{"source":"iptv_epg","id":"RaiPremium.it"},{"source":"open_epg_3","id":"Rai Premium.it"}]'),
  ('cielo', 'Cielo', 26, 'Nazionali', 'cielo.png', 'sky', '2', true,
    '[{"source":"sky","id":"8773","env":"DTT"},{"source":"iptv_epg","id":"cielo.it"},{"source":"open_epg_3","id":"Cielo.it"}]'),
  ('c27', 'Twentyseven', 27, 'Nazionali', 'twentyseven.png', 'mediaset', 'ts', true,
    '[{"source":"mediaset","id":"TS"},{"source":"sky","id":"11342","env":"DTH"},{"source":"open_epg_3","id":"Twenty Seven.it"}]'),
  ('tv2000', 'TV2000', 28, 'Nazionali', 'tv2000.png', NULL, 'https://hls-live-tv2000.akamaized.net/hls/live/2028510/tv2000/master.m3u8', true,
    '[{"source":"sky","id":"8325","env":"DTT"},{"source":"iptv_epg","id":"TV2000.it"},{"source":"open_epg_3","id":"TV2000.it"}]'),
  ('la7cinema', 'La7 Cinema', 29, 'Cinema', 'la7cinema.png', NULL, NULL, false,
    '[{"source":"sky","id":"6624","env":"DTT"},{"source":"iptv_epg","id":"La7D.it"},{"source":"open_epg_3","id":"La7 Cinema.it"}]'),
  ('la5', 'La5', 30, 'Nazionali', 'la5.png', 'mediaset', 'ka', true,
    '[{"source":"mediaset","id":"KA"},{"source":"sky","id":"6625","env":"DTT"},{"source":"iptv_epg","id":"La5.it"},{"source":"open_epg_3","id":"La 5.it"}]'),
  ('realtime', 'Real Time', 31, 'Intrattenimento', 'realtime.png', 'discovery', 'REALTIME', true,
    '[{"source":"discovery","id":"realtime"},{"source":"sky","id":"12122","env":"DTT"},{"source":"open_epg_3","id":"Real Time.it"},{"source":"iptv_epg","id":"RealTime.it"}]'),
  ('qvc', 'QVC', 32, 'Intrattenimento', 'qvc.png', NULL, 'https://qrg.akamaized.net/hls/live/2017383/lsqvc1it/master.m3u8', true,
    '[{"source":"open_epg_3","id":"QVC.it"},{"source":"open_epg_8","id":"QVC.it"},{"source":"iptv_epg","id":"QVC.it"}]'),
  ('foodnetwork', 'Food Network', 33, 'Intrattenimento', 'foodnetwork.png', 'discovery', 'FOODNETWORK', true,
    '[{"source":"discovery","id":"foodnetwork"},{"source":"sky","id":"12123","env":"DTH"},{"source":"iptv_epg","id":"FoodNetwork.it"},{"source":"open_epg_3","id":"FoodNetwork.it"}]'),
  ('cine34', 'Cine34', 34, 'Cinema', 'cine34.png', 'mediaset', 'b6', true,
    '[{"source":"mediaset","id":"B6"},{"source":"sky","id":"10893","env":"DTH"},{"source":"iptv_epg","id":"Cine34.it"},{"source":"open_epg_3","id":"Cine34.it"}]'),
  ('focus', 'Focus', 35, 'Documentari', 'focus.png', 'mediaset', 'fu', true,
    '[{"source":"mediaset","id":"FU"},{"source":"sky","id":"10470","env":"DTH"},{"source":"iptv_epg","id":"Focus.it"},{"source":"open_epg_3","id":"Focus.it"}]'),
  ('rtl1025', 'RTL 102.5', 36, 'Musica', 'rtl.png', NULL, 'https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S97044836/tbbP8T1ZRPBL/playlist_video.m3u8', true,
    '[{"source":"sky","id":"8320","env":"DTT"},{"source":"iptv_epg","id":"RTL1025.it"},{"source":"open_epg_3","id":"RTL 102.5 TV.it"}]'),
  ('discovery', 'Discovery', 37, 'Documentari', 'discovery.png', 'discovery', 'DISCOVERYCHANNEL', true,
    '[{"source":"open_epg_3","id":"Discovery.it"},{"source":"iptv_epg","id":"Discovery.it"},{"source":"sky","id":"12124","env":"DTH"}]'),
  ('giallo', 'Giallo', 38, 'Cinema', 'giallo.png', 'discovery', 'GIALLO', true,
    '[{"source":"sky","id":"12535","env":"DTT"},{"source":"iptv_epg","id":"GIALLO.it"},{"source":"open_epg_3","id":"Giallo.it"}]'),
  ('topcrime', 'Top Crime', 39, 'Cinema', 'topcrime.png', 'mediaset', 'lt', true,
    '[{"source":"mediaset","id":"LT"},{"source":"sky","id":"10468","env":"DTH"},{"source":"iptv_epg","id":"TOPcrime.it"},{"source":"open_epg_3","id":"Top Crime.it"}]'),
  ('boing', 'Boing', 40, 'Bambini', 'boing.png', 'mediaset', 'kb', true,
    '[{"source":"mediaset","id":"KB"},{"source":"iptv_epg","id":"Boing.it"},{"source":"open_epg_3","id":"Boing.it"}]'),
  ('raigulp', 'Rai Gulp', 42, 'Bambini', 'raigulp.png', 'rai', '746953', true,
    '[{"source":"rai","id":"rai-gulp"},{"source":"sky","id":"6629","env":"DTT"},{"source":"iptv_epg","id":"RaiGulp.it"},{"source":"open_epg_3","id":"Rai Gulp.it"}]'),
  ('raiyoyo', 'Rai Yoyo', 43, 'Bambini', 'raiyoyo.png', 'rai', '746899', true,
    '[{"source":"rai","id":"rai-yoyo"},{"source":"sky","id":"6609","env":"DTT"},{"source":"iptv_epg","id":"RaiYoyo.it"},{"source":"open_epg_3","id":"Rai Yoyo.it"}]'),
  ('cartoonito', 'Cartoonito', 46, 'Bambini', 'cartoonito.png', 'mediaset', 'la', true,
    '[{"source":"mediaset","id":"LA"},{"source":"iptv_epg","id":"CARTOONITO.it"},{"source":"open_epg_3","id":"Cartoonito.it"}]'),
  ('super', 'Super!', 47, 'Bambini', 'super.png', NULL, 'https://495c5a85d9074f29acffeaea9e0215eb.msvdn.net/super/super_main/super_main_hbbtv/playlist.m3u8', true,
    '[{"source":"sky","id":"8314","env":"DTT"},{"source":"iptv_epg","id":"Super!.it"},{"source":"open_epg_3","id":"Super!.it"}]'),
  ('rainews24', 'Rai News 24', 48, 'News', 'rainews24.png', 'rai', '1', true,
    '[{"source":"rai","id":"rai-news-24"},{"source":"sky","id":"895","env":"DTH"},{"source":"iptv_epg","id":"RaiNews.it"},{"source":"open_epg_3","id":"RaiNews24.it"}]'),
  ('italia2', 'Italia 2', 49, 'Nazionali', 'italia2.png', 'mediaset', 'i2', true,
    '[{"source":"mediaset","id":"I2"},{"source":"sky","id":"10469","env":"DTH"},{"source":"iptv_epg","id":"Italia2.it"},{"source":"open_epg_3","id":"Italia 2.it"}]'),
  ('skytg24', 'Sky TG24', 50, 'News', 'skytg24.png', 'sky', '1', true,
    '[{"source":"sky","id":"9313","env":"DTT"},{"source":"iptv_epg","id":"SkyTG24.it"},{"source":"open_epg_3","id":"Sky Tg24.it"}]'),
  ('tgcom24', 'TGCOM24', 51, 'News', 'tgcom24.png', 'mediaset', 'kf', true,
    '[{"source":"mediaset","id":"KF"},{"source":"sky","id":"10473","env":"DTT"},{"source":"iptv_epg","id":"TgCom24.it"},{"source":"open_epg_3","id":"Tgcom24.it"}]'),
  ('dmax', 'DMAX', 52, 'Intrattenimento', 'dmax.png', 'discovery', 'DMAX', true,
    '[{"source":"discovery","id":"dmaxit"},{"source":"sky","id":"12540","env":"DTT"},{"source":"iptv_epg","id":"DMAX.it"},{"source":"open_epg_3","id":"DMAX.it"}]'),
  ('casaitalia53', 'Casa Italia 53', 53, 'Intrattenimento', 'casaitalia53.png', NULL, 'https://ovp-live.akamaized.net/ac115_live/canale3.smil/playlist.m3u8', true,
    '[]'),
  ('raistoria', 'Rai Storia', 54, 'Documentari', 'raistoria.png', 'rai', '746990', true,
    '[{"source":"rai","id":"rai-storia"},{"source":"sky","id":"6630","env":"DTT"},{"source":"iptv_epg","id":"RaiStoria.it"},{"source":"open_epg_3","id":"Rai Storia.it"}]'),
  ('mediasetextra', 'Mediaset Extra', 55, 'Nazionali', 'mediasetextra.png', 'mediaset', 'kq', true,
    '[{"source":"mediaset","id":"KQ"},{"source":"sky","id":"6627","env":"DTT"},{"source":"iptv_epg","id":"MediasetExtra.it"},{"source":"open_epg_3","id":"Mediaset Extra.it"}]'),
  ('hgtv', 'HGTV', 56, 'Intrattenimento', 'hgtv.png', 'discovery', 'HGTV', true,
    '[{"source":"discovery","id":"hgtvit"},{"source":"sky","id":"12127","env":"DTH"},{"source":"iptv_epg","id":"HGTV.it"}]'),
  ('raiscuola', 'Italiana', 57, 'Documentari', 'raiscuola.png', 'rai', '747011', true,
    '[{"source":"rai","id":"italiana"},{"source":"open_epg_3","id":"Italiana.it"},{"source":"iptv_epg","id":"RaiScuola.it"}]'),
  ('raisport', 'Rai Sport', 58, 'Sport', 'raisport.png', 'rai', '358025', true,
    '[{"source":"rai","id":"rai-sport"},{"source":"sky","id":"8317","env":"DTT"},{"source":"iptv_epg","id":"RAISport.it"},{"source":"open_epg_8","id":"Rai Sport.it"}]'),
  ('discoveryturbo', 'Discovery Turbo', 59, 'Intrattenimento', 'discoveryturbo.png', 'discovery', 'TURBO', true,
    '[{"source":"discovery","id":"motortrend"},{"source":"sky","id":"12131","env":"DTH"},{"source":"open_epg_3","id":"Discovery Turbo.it"},{"source":"iptv_epg","id":"MotorTrend.it"}]'),
  ('sportitalia', 'Sportitalia', 60, 'Sport', 'sportitalia.png', NULL, 'https://edge-001.streamup.eu/sportitalia/sihd_abr/playlist.m3u8', true,
    '[{"source":"open_epg_3","id":"Sportitalia.it"},{"source":"iptv_epg","id":"Sportitalia.it"},{"source":"open_epg_8","id":"Sportitalia.it"}]'),
  ('solocalcio', 'Solocalcio', 61, 'Sport', '', NULL, 'https://distribution.sportitalialive.it/sportitalia/sisolocalcio_abr/playlist.m3u8', true,
    '[]'),
  ('supertennis', 'SuperTennis', 64, 'Sport', 'supertennis.png', NULL, 'https://live-embed.supertennix.hiway.media/restreamer/supertennix_client/gpu-a-c0-16/restreamer/outgest/aa3673f1-e178-44a9-a947-ef41db73211a/manifest.m3u8', true,
    '[{"source":"sky","id":"8322","env":"DTT"},{"source":"iptv_epg","id":"SuperTennis.it"},{"source":"open_epg_3","id":"SuperTennis.it"}]'),
  ('radio105', 'Radio 105 TV', 66, 'Musica', 'radio105.png', 'mediaset_radio', 'ec', true,
    '[{"source":"mediaset","id":"EC"},{"source":"open_epg_3","id":"Radio 105.it"}]'),
  ('r101', 'R101 TV', 67, 'Musica', 'r101.png', 'mediaset_radio', 'er', true,
    '[{"source":"mediaset","id":"ER"},{"source":"open_epg_3","id":"R101.it"}]'),
  ('bomchannel', 'Bom Channel', 68, 'Intrattenimento', 'bomchannel.png', NULL, 'https://5f22d76e220e1.streamlock.net/canale6/canale6/playlist.m3u8', true,
    '[]'),
  ('deejaytv', 'Deejay TV', 69, 'Musica', 'deejay.png', NULL, 'https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S85984808/sMO0tz9Sr2Rk/playlist.m3u8', true,
    '[{"source":"sky","id":"462","env":"DTT"},{"source":"iptv_epg","id":"DeejayTV.it"},{"source":"open_epg_3","id":"Deejay TV.it"}]'),
  ('radioitalia', 'Radio Italia TV', 70, 'Musica', 'radioitalia.png', NULL, 'https://radioitaliatv.akamaized.net/hls/live/2093117/RadioitaliaTV/master.m3u8', true,
    '[{"source":"sky","id":"9833","env":"DTH"},{"source":"iptv_epg","id":"RadioItaliaTV.it"},{"source":"open_epg_3","id":"Radio Italia Tv.it"}]'),
  ('rai4k', 'Rai 4K', 101, 'Nazionali', 'rai4k.png', 'rai', '4465258', true,
    '[{"source":"rai","id":"rai-4k"}]'),
  ('kisskiss', 'Kiss Kiss TV', 158, 'Musica', 'kisskiss.png', NULL, 'https://58f12ffd2447a.streamlock.net/KKMulti/livestream/playlist.m3u8', true,
    '[]'),
  ('rairadio2', 'Rai Radio 2', 202, 'Musica', 'rairadio2.png', 'rai', '5674080', true,
    '[{"source":"rai","id":"rai-radio-2"}]'),
  ('virginradiotv', 'Virgin Radio TV', 257, 'Musica', 'virginradiotv.png', 'mediaset_radio', 'ew', true,
    '[{"source":"mediaset","id":"EW"},{"source":"open_epg_3","id":"Virgin Radio.it"}]'),
  ('radiofreccia', 'Radio Freccia', 258, 'Musica', 'radiofreccia.png', NULL, 'https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S3160845/0tuSetc8UFkF/playlist_video.m3u8', true,
    '[{"source":"sky","id":"10853","env":"DTT"},{"source":"iptv_epg","id":"RADIOFRECCIA.it"},{"source":"open_epg_8","id":"radiofreccia.it"}]'),
  ('rds', 'RDS Social TV', 265, 'Musica', 'rdssocialtv.png', NULL, 'https://stream.rdstv.radio/out/v1/ec85f72b87f04555aa41d616d5be41dc/index.m3u8', true,
    '[]'),
  ('radiozeta', 'Radio Zeta', 266, 'Musica', 'radiozeta.png', NULL, 'https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S9346184/XEx1LqlYbNic/playlist_video.m3u8', true,
    '[]'),
  ('rmctv', 'Radio Monte Carlo TV', NULL, 'Musica', 'radiomontecarlo.png', 'mediaset_radio', 'bb', true,
    '[{"source":"mediaset","id":"BB"},{"source":"iptv_epg","id":"RadioMonteCarlo.it"},{"source":"open_epg_3","id":"Radio Monte Carlo.it"}]'),
  ('m2o', 'm2o TV', NULL, 'Musica', 'm2otv.png', NULL, 'https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S62628868/uhdWBlkC1AoO/playlist.m3u8', true,
    '[]'),
  ('radiocapital', 'Radio Capital TV', NULL, 'Musica', 'radiocapital.png', NULL, 'https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S35394734/Z6U2wGoDYANk/playlist.m3u8', true,
    '[]');
