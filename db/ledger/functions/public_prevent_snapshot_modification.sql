CREATE OR REPLACE FUNCTION public.prevent_snapshot_modification()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        RAISE EXCEPTION 'Update on table acc_balance_snapshot_register is not allowed.';
    ELSIF (TG_OP = 'DELETE') THEN
        RAISE EXCEPTION 'Delete from table acc_balance_snapshot_register is not allowed.';
    END IF;
    
    RETURN NEW;
END;
$function$

