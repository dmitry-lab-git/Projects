CREATE OR REPLACE FUNCTION public.protect_existing_transactions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        RAISE EXCEPTION 'Изменение существующих строк запрещено';
    ELSIF (TG_OP = 'DELETE') THEN
        RAISE EXCEPTION 'Удаление существующих строк запрещено';
    END IF;
    RETURN NEW;
END;
$function$

