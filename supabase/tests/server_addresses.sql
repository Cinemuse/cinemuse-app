-- Local DB check for server_addresses (STR-08, renamed in REV-337; the old
-- name scraper_sites is gone) and api_keys (REV-337).
-- Signed-in users read every row, anon reads nothing, nobody but
-- migrations (or the Table Editor) can write, and a malformed row is refused.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/server_addresses.sql
-- Any failed check stops with an error; success prints "server_addresses: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000008', 'str08@test.local');

insert into public.server_addresses (key, address, note, display_name) values
  ('test_site', 'https://a.example', 'test', 'Test Site');
insert into public.server_addresses (key, address) values
  ('test_unnamed', 'https://b.example');
insert into public.api_keys (name, value) values ('test_key', 'secret');

-- Only https addresses, simple keys and names, no empty key value.
do $$
begin
  begin
    insert into public.server_addresses (key, address) values ('x', 'http://a.b');
    raise exception 'an http address was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.server_addresses (key, address) values ('x', 'https://');
    raise exception 'an address with no host was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.server_addresses (key, address) values ('Big Site', 'https://a.b');
    raise exception 'a key with spaces was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.api_keys (name, value) values ('Big Key', 'x');
    raise exception 'a key name with spaces was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.api_keys (name, value) values ('x', '');
    raise exception 'an empty key was accepted';
  exception when check_violation then null;
  end;
end $$;

-- The migration's rows (the hidden sites' rows are entered by hand), and
-- the old name is gone.
do $$
begin
  assert (select count(*) from public.server_addresses where key in
    ('kitsu_api', 'update_repo')) = 2,
    'a migration row is missing';
  assert to_regclass('public.scraper_sites') is null,
    'the old name scraper_sites is still there';
  assert (select address from public.server_addresses where key = 'update_repo')
    like 'https://api.github.com/repos/%', 'update_repo is not a GitHub repo';
end $$;

-- anon reads nothing.
set local role anon;
do $$
begin
  begin
    perform 1 from public.server_addresses;
    raise exception 'anon could read server_addresses';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.api_keys;
    raise exception 'anon could read api_keys';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- A signed-in user reads every row and can't write.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
do $$
begin
  assert (select address from public.server_addresses where key = 'test_site')
    = 'https://a.example', 'user reads the wrong address';
  assert (select display_name from public.server_addresses
    where key = 'test_site') = 'Test Site', 'user reads the wrong name';
  assert (select display_name from public.server_addresses
    where key = 'test_unnamed') = '', 'a row with no name is not empty';
  assert (select value from public.api_keys where name = 'test_key')
    = 'secret', 'user reads the wrong key';
  begin
    update public.server_addresses set address = 'https://evil.example';
    raise exception 'user could update';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.server_addresses;
    raise exception 'user could delete';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.server_addresses (key, address) values ('x', 'https://a.b');
    raise exception 'user could insert';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.api_keys set value = 'x';
    raise exception 'user could update a key';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.api_keys (name, value) values ('x', 'y');
    raise exception 'user could insert a key';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select 'server_addresses: ok';

rollback;
