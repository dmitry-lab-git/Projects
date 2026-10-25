CREATE OR REPLACE FUNCTION public.is_trigger_active(t_name text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN COALESCE(
        (SELECT is_enabled FROM public.trigger_control WHERE trigger_name = t_name), 
        TRUE
    );
END;
$function$

