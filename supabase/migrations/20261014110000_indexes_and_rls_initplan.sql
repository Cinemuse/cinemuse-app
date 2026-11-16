-- BE-08: indexes for the app's most common filters, and RLS policies that
-- read auth.uid() / auth.role() once per query instead of once per row
-- (`(select auth.uid())`, Supabase's auth_rls_initplan advice). Every
-- policy allows exactly the same rows as before. `reviews` is left alone
-- (kept for a future feature, user 2026-10-14).

-- Most watch_logs queries filter on user + title and sort by logged_at.
CREATE INDEX IF NOT EXISTS watch_logs_user_title_idx
  ON public.watch_logs (user_id, tmdb_id, media_type, logged_at DESC);

CREATE INDEX IF NOT EXISTS lists_user_id_idx ON public.lists (user_id);

ALTER POLICY "Users manage own lists" ON public.lists
  USING ((select auth.uid()) = user_id);

ALTER POLICY "Users manage own list items" ON public.list_items
  USING (EXISTS (
    SELECT 1 FROM public.lists
    WHERE lists.id = list_items.list_id
      AND lists.user_id = (select auth.uid())
  ));

ALTER POLICY "Users can update own profile" ON public.profiles
  USING ((select auth.uid()) = id);

ALTER POLICY "Users manage own history" ON public.watch_history
  USING ((select auth.uid()) = user_id);

ALTER POLICY "Users manage own logs" ON public.watch_logs
  USING ((select auth.uid()) = user_id);

ALTER POLICY "Authenticated users can insert media cache" ON public.media_cache
  WITH CHECK ((select auth.role()) = 'authenticated');
