-- REV-337: the addresses the app reads from the server instead of having
-- them built in, in one list. `scraper_sites` becomes `server_addresses`
-- and gets the outside services whose addresses can move. The app keeps a
-- built-in copy of these new rows (used with no server answer and no saved
-- copy), so their keys are readable; the other rows have none.
--
-- The Rai and Sky link services the default playlist asks are not here:
-- they are `tv_link_services` rows, and the playlist hands the device the
-- full address.

alter table public.scraper_sites rename to server_addresses;
alter table public.server_addresses
  rename constraint scraper_sites_pkey to server_addresses_pkey;
alter table public.server_addresses
  rename constraint scraper_sites_key_check to server_addresses_key_check;
alter table public.server_addresses
  rename constraint scraper_sites_address_check to server_addresses_address_check;
alter policy "Signed-in users read scraper sites" on public.server_addresses
  rename to "Signed-in users read server addresses";

-- The old name, read-only, until the app reads the new one; then dropped.
create view public.scraper_sites with (security_invoker = true) as
  select key, address, note from public.server_addresses;

revoke all on table public.scraper_sites from anon, authenticated;
grant select on table public.scraper_sites to authenticated;

insert into public.server_addresses (key, address, note) values
  ('kitsu_api', 'https://kitsu.app/api/edge',
    'Anime: Kitsu API'),
  ('update_repo', 'https://api.github.com/repos/Cinemuse/cinemuse-app',
    'Where app updates come from (an api.github.com/repos/ address only)');

-- Keys of outside services the app needs, handed over after sign-in and
-- kept on the device. Not in server_addresses: a key is not an address.
-- The values are entered in the Supabase website (Table Editor), never in
-- a migration.
create table public.api_keys (
  name text primary key check (name ~ '^[a-z0-9_]+$'),
  value text not null check (value <> ''),
  note text not null default ''
);

alter table public.api_keys enable row level security;

-- Signed-in users read; no write policy, so the app can't change it.
create policy "Signed-in users read api keys" on public.api_keys
  for select to authenticated
  using (true);

revoke all on table public.api_keys from anon, authenticated;
grant select on table public.api_keys to authenticated;
