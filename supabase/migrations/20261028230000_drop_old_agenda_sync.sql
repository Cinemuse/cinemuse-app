-- refresh-agenda keeps the agenda up to date, so the old sync-agenda goes.
-- Its triggers and nightly job went in 20261020163441_agenda_titles; this
-- is the function they called.

drop function public.trigger_sync_agenda();
