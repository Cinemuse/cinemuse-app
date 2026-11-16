-- The name the app shows for an address (a Settings switch, a stream row, a
-- review's label), downloaded with it, so the public code never names the
-- sites. Empty for a service whose name the app never shows. The names are
-- entered in the Supabase website (Table Editor), never in a migration.

alter table public.server_addresses
  add column display_name text not null default '';
