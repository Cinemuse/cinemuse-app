-- REV-306: the app talks straight to the tables, so a database change an
-- older release doesn't expect breaks it silently until the device updates.
-- This one-row table holds the oldest app version the database still
-- supports; at startup the app compares it with its own version and, when
-- it is older, shows "Update required" instead of the normal app.
--
-- Two-step migrations stay the normal way (PROJECT.md -> 8. Supabase ->
-- Older app releases keep working); this is the safety net.
--
-- Written only by migrations: to raise it,
--   update public.app_config set min_app_version = '1.5.0', updated_at = now();
-- '0.0.0' = no minimum. App releases older than this change never read it.

create table public.app_config (
  -- Always true: the table can hold one row only.
  id boolean primary key default true check (id),
  min_app_version text not null default '0.0.0'
    check (min_app_version ~ '^\d+\.\d+\.\d+(\+\d+)?$'),
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

-- Read before and after sign-in; no write policy, so the app can't change it.
create policy "Everyone reads app config" on public.app_config
  for select to anon, authenticated
  using (true);

revoke all on table public.app_config from anon, authenticated;
grant select on table public.app_config to anon, authenticated;

insert into public.app_config (id, min_app_version) values (true, '0.0.0');
