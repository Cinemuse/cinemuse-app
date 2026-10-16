-- Local DB check for REV-306 (migration 20261016225252_app_config).
-- anon and signed-in users read the one row, nobody but migrations can
-- write it, and the table can't get a second row or a malformed version.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/app_config.sql
-- Any failed check stops with an error; success prints "app_config: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000306', 'rev306@test.local');

-- One row only, and only x.y.z or x.y.z+n.
do $$
begin
  begin
    insert into public.app_config (id) values (false);
    raise exception 'a second row was accepted';
  exception when check_violation then null;
  end;
  begin
    update public.app_config set min_app_version = 'v1.2';
    raise exception 'a malformed version was accepted';
  exception when check_violation then null;
  end;
  update public.app_config set min_app_version = '1.4.0+7';
  update public.app_config set min_app_version = '0.0.0';
end $$;

-- anon reads it, can't write it.
set local role anon;
do $$
begin
  assert (select count(*) from public.app_config) = 1, 'anon reads no row';
  assert (select min_app_version from public.app_config) = '0.0.0',
    'anon reads the wrong version';
  begin
    update public.app_config set min_app_version = '9.9.9';
    raise exception 'anon could update';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- A signed-in user reads it, can't write or delete it.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000306","role":"authenticated"}', true);
do $$
begin
  assert (select min_app_version from public.app_config) = '0.0.0',
    'user reads the wrong version';
  begin
    update public.app_config set min_app_version = '9.9.9';
    raise exception 'user could update';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.app_config;
    raise exception 'user could delete';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.app_config (id) values (true);
    raise exception 'user could insert';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select 'app_config: ok';

rollback;
