-- Parts of the shared title cache and of the lists that nothing uses.
-- crew_members was never filled; cast_members was uploaded but never read (a
-- title page gets its cast from TMDB); lists.settings is empty in every list;
-- idx_media_tmdb covers the same columns as the table's primary key.
alter table public.media_cache
  drop column crew_members,
  drop column cast_members;

alter table public.lists
  drop column settings;

drop index public.idx_media_tmdb;
