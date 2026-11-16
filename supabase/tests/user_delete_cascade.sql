-- Local DB check for REV-258 (migration 20261013150000_user_delete_cascade).
-- A user can be deleted (profile and lists go with it), but a signed-in user
-- still can't delete their own Watchlist / Favorites; a custom list they can.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/user_delete_cascade.sql
-- Any failed check stops with an error; success prints "user_delete_cascade: ok".

begin;

-- The new-user trigger makes the profile and the Watchlist / Favorites lists.
insert into auth.users (id, email)
values ('00000000-0000-4000-8000-000000000258', 'rev258@test.local');

insert into public.lists (user_id, name)
values ('00000000-0000-4000-8000-000000000258', 'My custom list');

do $$
begin
  assert (select count(*) from public.profiles
          where id = '00000000-0000-4000-8000-000000000258') = 1,
    'the new user has no profile';
  assert (select array_agg(type::text order by type::text) from public.lists
          where user_id = '00000000-0000-4000-8000-000000000258')
         = array['custom', 'favorites', 'watchlist'],
    'the new user does not have Watchlist, Favorites and the custom list';
end $$;

-- As the signed-in user.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000258","role":"authenticated"}', true);

do $$
declare
  list_type text;
  err text;
  deleted int;
begin
  foreach list_type in array array['watchlist', 'favorites'] loop
    err := null;
    begin
      delete from public.lists
      where user_id = '00000000-0000-4000-8000-000000000258'
        and type::text = list_type;
    exception when others then
      err := sqlerrm;
    end;
    assert err = 'Cannot delete system lists',
      format('deleting the %s gave: %s', list_type, coalesce(err, 'no error'));
  end loop;

  delete from public.lists
  where user_id = '00000000-0000-4000-8000-000000000258' and type = 'custom';
  get diagnostics deleted = row_count;
  assert deleted = 1, 'the custom list was not deleted';
end $$;

reset role;

-- Deleting the user removes the profile and the remaining lists.
delete from auth.users where id = '00000000-0000-4000-8000-000000000258';

do $$
begin
  assert not exists (select 1 from public.profiles
                     where id = '00000000-0000-4000-8000-000000000258'),
    'the profile is still there';
  assert not exists (select 1 from public.lists
                     where user_id = '00000000-0000-4000-8000-000000000258'),
    'the lists are still there';
end $$;

\echo 'user_delete_cascade: ok'

rollback;
