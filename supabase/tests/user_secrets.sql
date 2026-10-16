-- Local DB check for SEC-04 (migration 20261016185318_user_secrets).
-- A user reads and saves only their own secrets, a save changes only the
-- keys it sends, anon reads nothing, patch_preferences never stores a key in
-- profiles, and deleting the user deletes the row.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/user_secrets.sql
-- Any failed check stops with an error; success prints "user_secrets: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000005e1', 'sec04a@test.local'),
  ('00000000-0000-4000-8000-0000000005e2', 'sec04b@test.local');

insert into public.user_secrets (user_id, secrets)
values ('00000000-0000-4000-8000-0000000005e2', '{"torBoxKey": "key-of-b"}');

-- As user A.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000005e1","role":"authenticated"}', true);

-- The app's saves: the first makes the row, the second changes one key.
select public.patch_secrets('{"realDebridKey": "key-of-a"}');
select public.patch_secrets('{"torBoxKey": "tb-of-a"}');

select public.patch_preferences(
  '{"showSubtitles": false, "realDebridKey": "leak", "installedAddons": []}'
);

do $$
declare
  err text;
begin
  assert (select count(*) from public.user_secrets) = 1,
    'user A sees another user''s secrets';
  assert (select secrets from public.user_secrets)
         = '{"realDebridKey": "key-of-a", "torBoxKey": "tb-of-a"}'::jsonb,
    'the second save changed a key it did not send';
  assert (select preferences from public.profiles
          where id = '00000000-0000-4000-8000-0000000005e1')
         = '{"showSubtitles": false}'::jsonb,
    'patch_preferences stored a secret key in profiles';

  begin
    perform public.patch_secrets('[]');
  exception when others then
    err := sqlerrm;
  end;
  assert err is not null, 'patch_secrets took a patch that is not an object';
end $$;

-- RLS hides user B's row from A's update (no error, nothing changes).
update public.user_secrets set secrets = '{"torBoxKey": "overwrite"}'
where user_id = '00000000-0000-4000-8000-0000000005e2';

reset role;
do $$
begin
  assert (select secrets ->> 'torBoxKey' from public.user_secrets
          where user_id = '00000000-0000-4000-8000-0000000005e2') = 'key-of-b',
    'user A could write user B''s secrets';
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

  err := null;
  begin
    perform public.patch_secrets('{"torBoxKey": "x"}');
  exception when others then
    err := sqlerrm;
  end;
  assert err is not null, 'anon can call patch_secrets';
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
