-- Local DB check for SEC-04 (migration 20261016185318_user_secrets).
-- A user reads and saves only their own secrets row, anon reads nothing,
-- patch_preferences never stores a key in profiles, and deleting the user
-- deletes the row.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/user_secrets.sql
-- Any failed check stops with an error; success prints "user_secrets: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000005e1', 'sec04a@test.local'),
  ('00000000-0000-4000-8000-0000000005e2', 'sec04b@test.local');

insert into public.user_secrets (user_id, torbox_key)
values ('00000000-0000-4000-8000-0000000005e2', 'key-of-b');

-- As user A.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000005e1","role":"authenticated"}', true);

-- The app's save: an upsert of the changed columns only.
insert into public.user_secrets (user_id, real_debrid_key)
values ('00000000-0000-4000-8000-0000000005e1', 'key-of-a')
on conflict (user_id) do update set real_debrid_key = excluded.real_debrid_key;
insert into public.user_secrets (user_id, torbox_key)
values ('00000000-0000-4000-8000-0000000005e1', 'tb-of-a')
on conflict (user_id) do update set torbox_key = excluded.torbox_key;

select public.patch_preferences(
  '{"showSubtitles": false, "realDebridKey": "leak", "installedAddons": []}'
);

do $$
declare
  err text;
begin
  assert (select count(*) from public.user_secrets) = 1,
    'user A sees another user''s secrets';
  assert (select real_debrid_key || '/' || torbox_key from public.user_secrets)
         = 'key-of-a/tb-of-a',
    'the second save changed a column it did not send';
  assert (select preferences from public.profiles
          where id = '00000000-0000-4000-8000-0000000005e1')
         = '{"showSubtitles": false}'::jsonb,
    'patch_preferences stored a secret key in profiles';

  begin
    insert into public.user_secrets (user_id, torbox_key)
    values ('00000000-0000-4000-8000-0000000005e2', 'overwrite')
    on conflict (user_id) do update set torbox_key = excluded.torbox_key;
  exception when others then
    err := sqlerrm;
  end;
  assert err is not null, 'user A could write user B''s secrets';
end $$;

-- As anon.
reset role;
set local role anon;

do $$
declare
  err text;
begin
  begin
    perform 1 from public.user_secrets;
  exception when others then
    err := sqlerrm;
  end;
  assert err is not null, 'anon can read user_secrets';
end $$;

-- Deleting the user deletes their secrets.
reset role;
delete from auth.users where id = '00000000-0000-4000-8000-0000000005e1';

do $$
begin
  assert not exists (select 1 from public.user_secrets
                     where user_id = '00000000-0000-4000-8000-0000000005e1'),
    'the deleted user''s secrets are still there';
end $$;

select 'user_secrets: ok';

rollback;
