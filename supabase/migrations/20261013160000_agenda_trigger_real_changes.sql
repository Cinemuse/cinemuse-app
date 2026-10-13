-- BE-04: `UPDATE OF status, season, episode` fires whenever those columns are
-- in the SET list, even unchanged. The app's progress upsert sends them every
-- 15 s, so each progress save called the sync-agenda edge function (and
-- TMDB). Now: on insert, and on an update only when one of them changed.

DROP TRIGGER on_watch_history_inserted ON public.watch_history;

CREATE TRIGGER on_watch_history_inserted
  AFTER INSERT ON public.watch_history
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_sync_agenda();

CREATE TRIGGER on_watch_history_changed
  AFTER UPDATE OF status, season, episode ON public.watch_history
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
     OR OLD.season IS DISTINCT FROM NEW.season
     OR OLD.episode IS DISTINCT FROM NEW.episode)
  EXECUTE FUNCTION public.trigger_sync_agenda();
