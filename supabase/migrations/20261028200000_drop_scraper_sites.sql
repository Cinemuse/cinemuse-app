-- The app reads server_addresses by its own name now, so the old name's
-- read-only view goes.

drop view public.scraper_sites;
