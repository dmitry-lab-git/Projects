CREATE OR REPLACE FUNCTION public.fn_general_update_limiter()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- ПРИНУДИТЕЛЬНЫЙ ВЫХОД, если в таблице стоит FALSE
    IF NOT public.is_trigger_active('trg_lock_transactions') THEN
        RETURN NEW;
    END IF;

    -- Если триггер активен, тогда и только тогда проверяем сессию
    IF current_setting('app.allow_maintenance', true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Обновление заблокировано. Для выполнения операции установите SET app.allow_maintenance = ''true'';';
    END IF;

    RETURN NEW;
END;
$function$

