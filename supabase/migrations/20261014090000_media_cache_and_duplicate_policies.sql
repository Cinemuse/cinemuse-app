-- BE-05 (rest): media_cache had a FOR ALL policy, so any signed-in user could
-- rewrite or delete shared metadata, plus duplicate SELECT policies on
-- media_cache and upcoming_agenda_cache. The app only upserts media_cache
-- (insert + update), never deletes. The `reviews` table is left as it is
-- (empty, kept for a future review feature: user, 2026-10-14).

DROP POLICY "Allow authenticated users to insert/update media_cache" ON public.media_cache;

-- Same as "Media cache viewable by everyone" (TO PUBLIC), which stays.
DROP POLICY "Allow public read access to media_cache" ON public.media_cache;

-- "Authenticated users can insert media cache" stays for inserts.
CREATE POLICY "Authenticated users can update media cache" ON public.media_cache
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Same as "Allow read access to all authenticated users", which stays.
DROP POLICY "Enable read access for authenticated users" ON public.upcoming_agenda_cache;
