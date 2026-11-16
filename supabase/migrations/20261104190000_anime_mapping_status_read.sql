-- Signed-in users may read the anime list's refresh note: when it was last
-- refreshed, and the last failure. A list that stops refreshing keeps answering
-- correctly, so this note is the only way to see it from outside. The note holds
-- no personal data. Nothing changes for writing: only the server writes it.

CREATE POLICY "Signed-in users read the refresh note"
  ON public.anime_mapping_status
  FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.anime_mapping_status TO authenticated;
