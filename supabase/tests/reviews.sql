-- Local DB check for the `reviews` table (a user's own ratings and reviews).
-- One rating per title per account, 1 to 10, films and series only, private to
-- its owner, gone with the account.
--
-- Run on the local stack (safe to run again, everything is rolled back):
--   docker exec -i supabase_db_cinemuse-app psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/reviews.sql
-- Any failed check stops with an error; success prints "reviews: ok".

begin;

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'reviews-owner@test.local'),
  ('00000000-0000-4000-8000-0000000000a2', 'reviews-other@test.local');

-- The table's shape and rights.
do $$
begin
  assert not exists (select 1 from pg_type where typname = 'review_target'),
    'the old review_target type is still there';
  assert (select relrowsecurity from pg_class where oid = 'public.reviews'::regclass),
    'row-level security is off';
  assert not has_table_privilege('anon', 'public.reviews', 'select,insert,update,delete,truncate'),
    'signed-out users have rights on the table';
  assert not has_table_privilege('authenticated', 'public.reviews', 'truncate,references,trigger'),
    'signed-in users have more rights than they need';
  assert not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and tablename = 'reviews'),
    'the table streams live, and it should not';
end $$;

-- As the owner.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);

do $$
declare
  owner_id constant uuid := '00000000-0000-4000-8000-0000000000a1';
  first_created timestamptz := '2026-01-01T10:00:00Z';
  bad record;
  refused boolean;
begin
  -- A rating with no text, as the app saves it.
  insert into public.reviews (user_id, tmdb_id, media_type, rating, created_at, updated_at)
  values (owner_id, 438631, 'movie', 9, first_created, first_created);

  -- Saving again overwrites the same row and keeps when it was first made.
  insert into public.reviews (user_id, tmdb_id, media_type, rating, review_text, updated_at)
  values (owner_id, 438631, 'movie', 7, '**Great** visuals', now())
  on conflict (user_id, tmdb_id, media_type) do update
    set rating = excluded.rating,
        review_text = excluded.review_text,
        updated_at = excluded.updated_at;

  assert (select count(*) from public.reviews where tmdb_id = 438631) = 1,
    'saving twice made two rows';
  assert (select rating from public.reviews where tmdb_id = 438631) = 7,
    'the second save did not overwrite the score';
  assert (select review_text from public.reviews where tmdb_id = 438631) = '**Great** visuals',
    'the text was not saved as typed';
  assert (select created_at from public.reviews where tmdb_id = 438631) = first_created,
    'saving again changed when it was first made';
  assert (select updated_at from public.reviews where tmdb_id = 438631) > first_created,
    'saving again did not change when it was last changed';

  -- TMDB's film and series ids overlap: the same number is two titles.
  insert into public.reviews (user_id, tmdb_id, media_type, rating)
  values (owner_id, 438631, 'tv', 3);
  assert (select count(*) from public.reviews where tmdb_id = 438631) = 2,
    'a film and a series with the same id are not separate';

  -- The lowest and highest scores are allowed.
  insert into public.reviews (user_id, tmdb_id, media_type, rating) values
    (owner_id, 1, 'movie', 1),
    (owner_id, 2, 'movie', 10);

  -- Scores out of range, a missing score and an episode are refused.
  for bad in
    select * from (values
      (0::smallint, 'movie'::public.media_kind),
      (11::smallint, 'movie'::public.media_kind),
      (null::smallint, 'movie'::public.media_kind),
      (5::smallint, 'episode'::public.media_kind)
    ) as t (rating, media_type)
  loop
    refused := false;
    begin
      insert into public.reviews (user_id, tmdb_id, media_type, rating)
      values (owner_id, 3, bad.media_type, bad.rating);
    exception when check_violation or not_null_violation then
      refused := true;
    end;
    assert refused, format('score %s on a %s was accepted', bad.rating, bad.media_type);
  end loop;

  -- The owner can remove their own.
  delete from public.reviews where user_id = owner_id and tmdb_id = 1;
  assert not exists (select 1 from public.reviews where tmdb_id = 1),
    'the owner could not remove their rating';
end $$;

-- As another signed-in user.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);

do $$
declare
  owner_id constant uuid := '00000000-0000-4000-8000-0000000000a1';
  changed int;
  refused boolean := false;
begin
  assert (select count(*) from public.reviews) = 0,
    'another user can read the ratings';

  update public.reviews set rating = 1 where user_id = owner_id;
  get diagnostics changed = row_count;
  assert changed = 0, 'another user changed a rating';

  delete from public.reviews where user_id = owner_id;
  get diagnostics changed = row_count;
  assert changed = 0, 'another user removed a rating';

  begin
    insert into public.reviews (user_id, tmdb_id, media_type, rating)
    values (owner_id, 4, 'movie', 5);
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'another user saved a rating on the owner''s account';

  -- They can have their own rating of the same title.
  insert into public.reviews (user_id, tmdb_id, media_type, rating)
  values ('00000000-0000-4000-8000-0000000000a2', 438631, 'movie', 2);
end $$;

-- Signed out.
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

do $$
declare
  refused boolean := false;
begin
  begin
    perform 1 from public.reviews;
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'a signed-out user can read the table';
end $$;

reset role;

-- The owner's rows are all there, and the other user's rating did not touch them.
do $$
begin
  assert (select count(*) from public.reviews
          where user_id = '00000000-0000-4000-8000-0000000000a1') = 3,
    'the owner should have three ratings left';
end $$;

-- Deleting the account removes its ratings and leaves the other account's.
delete from auth.users where id = '00000000-0000-4000-8000-0000000000a1';

do $$
begin
  assert not exists (select 1 from public.reviews
                     where user_id = '00000000-0000-4000-8000-0000000000a1'),
    'the ratings outlived the account';
  assert (select count(*) from public.reviews
          where user_id = '00000000-0000-4000-8000-0000000000a2') = 1,
    'deleting one account removed another account''s rating';
end $$;

\echo 'reviews: ok'

rollback;
