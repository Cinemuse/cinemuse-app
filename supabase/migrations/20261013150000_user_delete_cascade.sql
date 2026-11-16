-- REV-258: deleting a user failed ("Database error deleting user").
-- auth.users -> profiles already cascades, but four tables pointed at
-- profiles without ON DELETE CASCADE, and protect_system_lists refused to
-- delete the Watchlist / Favorites lists every user has.

ALTER TABLE public.lists
  DROP CONSTRAINT lists_user_id_fkey,
  ADD CONSTRAINT lists_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.reviews
  DROP CONSTRAINT reviews_user_id_fkey,
  ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.watch_history
  DROP CONSTRAINT watch_history_user_id_fkey,
  ADD CONSTRAINT watch_history_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.watch_logs
  DROP CONSTRAINT watch_logs_user_id_fkey,
  ADD CONSTRAINT watch_logs_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.profiles(id) ON DELETE CASCADE;

-- System lists stay protected while their owner exists. When the profile is
-- being deleted it is already gone here, so the cascade may remove them.
CREATE OR REPLACE FUNCTION public.protect_system_lists()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path = ''
  AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.type IN ('watchlist', 'favorites')
       AND EXISTS (SELECT 1 FROM public.profiles WHERE id = OLD.user_id) THEN
      RAISE EXCEPTION 'Cannot delete system lists';
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.type IN ('watchlist', 'favorites') AND NEW.type != OLD.type THEN
      RAISE EXCEPTION 'Cannot change the type of a system list';
    END IF;
    RETURN NEW;
  END IF;
END;
$function$;
