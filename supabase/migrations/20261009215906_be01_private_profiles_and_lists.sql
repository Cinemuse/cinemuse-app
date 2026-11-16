-- BE-01 / BE-05 (audit/09-supabase-backend.md): profiles, lists and list items
-- were readable by anyone holding the public anon key, including the API keys
-- stored in profiles.preferences. Make them owner-only.
--
-- The app only ever reads rows of the signed-in user, so nothing in lib/ breaks.
-- Owner access to lists/list_items stays via the existing "Users manage own ..."
-- policies (FOR ALL, which includes SELECT).

-- profiles: only the owner can read their row
drop policy "Public profiles are viewable by everyone" on public.profiles;

create policy "Users read own profile" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

-- lists & list items: drop the public read policies
drop policy "Public lists viewable" on public.lists;
drop policy "Public list items viewable" on public.list_items;
