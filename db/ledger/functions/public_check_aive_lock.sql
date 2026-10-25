CREATE OR REPLACE FUNCTION public.check_aive_lock()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    RAISE EXCEPTION 'Ledger is read-only. Use refresh_ledger() to update data.';
END;
$function$

