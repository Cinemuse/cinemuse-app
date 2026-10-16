-- DATA-02b (audit/02-data-integrity.md): saving a setting replaced the whole
-- profiles.preferences object, so a device holding old or default values
-- wrote them over every other setting. This merges only the keys that
-- changed into the stored object, in one statement.
--
-- p_patch: json object of the changed keys only (a key set to null is
-- stored as null; nothing is removed).
-- Returns the merged preferences, so the app can update its local cache.
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
  set preferences = coalesce(preferences, '{}'::jsonb) || p_patch,
      updated_at = now()
  where id = v_user_id
  returning preferences into v_preferences;

  if not found then
    raise exception 'patch_preferences: no profile' using errcode = 'P0002';
  end if;

  return v_preferences;
end;
$$;

revoke execute on function public.patch_preferences(jsonb) from public, anon;

grant execute on function public.patch_preferences(jsonb) to authenticated;
