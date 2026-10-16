-- SEC-04 (audit/01-security.md): the debrid / OpenSubtitles keys and the
-- installed addons (their URLs often hold a debrid key) were stored in
-- profiles.preferences. Move them to their own owner-only table, so a
-- future change to who can read profiles can't expose them.
--
-- One row per user, made by the app on its first save (upsert).

create table public.user_secrets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  real_debrid_key text not null default '',
  torbox_key text not null default '',
  opensubtitles_key text not null default '',
  installed_addons jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_secrets enable row level security;

create policy "Users read own secrets" on public.user_secrets
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert own secrets" on public.user_secrets
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update own secrets" on public.user_secrets
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.user_secrets from anon, authenticated;
grant select, insert, update on table public.user_secrets to authenticated;

-- Move the stored values, then remove them from preferences.
insert into public.user_secrets (
  user_id, real_debrid_key, torbox_key, opensubtitles_key, installed_addons
)
select
  p.id,
  coalesce(p.preferences ->> 'realDebridKey', ''),
  coalesce(p.preferences ->> 'torBoxKey', ''),
  coalesce(p.preferences ->> 'openSubtitlesKey', ''),
  case
    when jsonb_typeof(p.preferences -> 'installedAddons') = 'array'
      then p.preferences -> 'installedAddons'
    else '[]'::jsonb
  end
from public.profiles p
where p.preferences ?| array[
  'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
];

update public.profiles
set preferences = preferences
  - array['realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons']
where preferences ?| array[
  'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
];

-- patch_preferences (DATA-02b) must never put them back.
create or replace function public.patch_preferences(p_patch jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_preferences jsonb;
begin
  if v_user_id is null then
    raise exception 'patch_preferences: not signed in' using errcode = '28000';
  end if;

  if jsonb_typeof(p_patch) is distinct from 'object' then
    raise exception 'patch_preferences: patch must be an object'
      using errcode = '22023';
  end if;

  update public.profiles
  set preferences = coalesce(preferences, '{}'::jsonb)
      || (p_patch - array[
        'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
      ]),
      updated_at = now()
  where id = v_user_id
  returning preferences into v_preferences;

  if not found then
    raise exception 'patch_preferences: no profile' using errcode = 'P0002';
  end if;

  return v_preferences;
end;
$$;
