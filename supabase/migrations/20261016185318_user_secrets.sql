-- SEC-04 (audit/01-security.md): the debrid / OpenSubtitles keys and the
-- installed addons (their URLs often hold a debrid key) were stored in
-- profiles.preferences. Copy them to their own owner-only table, so a
-- future change to who can read profiles can't expose them.
--
-- One row per user. `secrets` is one object (realDebridKey, torBoxKey,
-- openSubtitlesKey, installedAddons, ...), so a new key needs no migration.
-- The app saves through patch_secrets, which merges only the changed keys.
--
-- The old copies stay in preferences for now: app releases older than this
-- change still read them there. A later migration removes them once every
-- device runs the new app.

create table public.user_secrets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  secrets jsonb not null default '{}'::jsonb
    check (jsonb_typeof(secrets) = 'object'),
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

-- Copy the stored values (the originals stay, see above).
insert into public.user_secrets (user_id, secrets)
select
  p.id,
  (select jsonb_object_agg(e.key, e.value)
   from jsonb_each(p.preferences) e
   where e.key = any (array[
     'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
   ]))
from public.profiles p
where jsonb_typeof(p.preferences) = 'object'
  and p.preferences ?| array[
    'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
  ];

-- Merges p_patch into the signed-in user's secrets (making the row on the
-- first save) and returns the result. Security invoker: the policies above
-- still apply.
create function public.patch_secrets(p_patch jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_secrets jsonb;
begin
  if v_user_id is null then
    raise exception 'patch_secrets: not signed in' using errcode = '28000';
  end if;

  if jsonb_typeof(p_patch) is distinct from 'object' then
    raise exception 'patch_secrets: patch must be an object'
      using errcode = '22023';
  end if;

  insert into public.user_secrets as s (user_id, secrets)
  values (v_user_id, p_patch)
  on conflict (user_id) do update
  set secrets = s.secrets || excluded.secrets,
      updated_at = now()
  returning s.secrets into v_secrets;

  return v_secrets;
end;
$$;

revoke execute on function public.patch_secrets(jsonb) from public, anon;
grant execute on function public.patch_secrets(jsonb) to authenticated;

-- patch_preferences (DATA-02b): the new app never writes these keys to
-- preferences; drop them if it ever tries.
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
