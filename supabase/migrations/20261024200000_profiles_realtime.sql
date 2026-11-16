-- REV-348: the app watches its own profile live (pins and preferences changed
-- on another device), but profiles was never in the realtime publication, so
-- every subscribe failed and was retried. Row-level security already limits
-- each user to their own row.

alter publication supabase_realtime add table public.profiles;
