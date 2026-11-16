-- A user's own rating and review of a film or a whole series, 1 to 10, one per
-- title per account. The old `reviews` table is replaced rather than changed:
-- it was never used, it is empty, and its rule let anyone read every row, even
-- signed out, while these are private to their owner.

drop table public.reviews;
drop type public.review_target;

create table public.reviews (
  user_id uuid not null references public.profiles (id) on delete cascade,
  tmdb_id bigint not null,
  -- media_kind also allows 'episode'; only whole titles can be rated.
  media_type public.media_kind not null check (media_type in ('movie', 'tv')),
  rating smallint not null check (rating between 1 and 10),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, tmdb_id, media_type)
);

alter table public.reviews enable row level security;

create policy "Users manage own reviews" on public.reviews
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on table public.reviews from anon, authenticated;
grant select, insert, update, delete on table public.reviews to authenticated;
