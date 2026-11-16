-- STR-08: the addresses of the sites the app scrapes (the built-in sources,
-- the sport schedule). They move often; kept here instead of in the app, a
-- move is fixed by editing one row in the Supabase website (Table Editor),
-- with no app release. The app has no copy of its own: it keeps the last
-- list it downloaded. The rows are entered in the Table Editor, never in a
-- migration.
--
-- One row per site. `key` is what the app looks for (never rename one: the
-- released apps read it); `address` is what the user edits when a site
-- moves; `note` says what the app uses it for.

create table public.scraper_sites (
  key text primary key check (key ~ '^[a-z0-9_]+$'),
  address text not null check (address ~ '^https://[^/\s]+(/\S*)?$'),
  note text not null default ''
);

alter table public.scraper_sites enable row level security;

-- Signed-in users read (the app, the daily telemetry with its own account);
-- no write policy, so the app can't change it.
create policy "Signed-in users read scraper sites" on public.scraper_sites
  for select to authenticated
  using (true);

revoke all on table public.scraper_sites from anon, authenticated;
grant select on table public.scraper_sites to authenticated;
