CREATE OR REPLACE FUNCTION public.fn_is_trigger_enabled(t_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
    SELECT COALESCE((SELECT is_enabled FROM public.trigger_control WHERE trigger_name = t_name), TRUE);
$function$

