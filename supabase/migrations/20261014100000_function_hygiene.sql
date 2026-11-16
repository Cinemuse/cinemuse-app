-- BE-06: function hygiene (Security Advisor).
-- Trigger functions were callable by anon / authenticated through
-- /rest/v1/rpc. A direct call fails ("trigger functions can only be called
-- as triggers"), but revoke anyway. Postgres checks EXECUTE only when a
-- trigger is created, not when it fires, so the triggers keep working.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trigger_sync_agenda() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_history_from_log() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.protect_system_lists() FROM PUBLIC, anon, authenticated;

-- Both already name every table with its schema (public., net.).
-- sync_history_from_log and protect_system_lists have it already.
ALTER FUNCTION public.handle_new_user() SET search_path = '';
ALTER FUNCTION public.trigger_sync_agenda() SET search_path = '';

-- Same job as sync_history_from_log, attached to no trigger.
DROP FUNCTION public.update_watch_history_from_logs();
