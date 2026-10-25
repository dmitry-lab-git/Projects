CREATE OR REPLACE FUNCTION audit.trg_refresh_system_after_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- ПРОВЕРКА: Если триггер выключен в пульте — выходим
    IF NOT public.is_trigger_active('trg_refresh_system_after_change') THEN
        RETURN NEW;
    END IF;

    -- Защита от бесконечной рекурсии
    IF (pg_trigger_depth() > 0) THEN
        RETURN NEW;
    END IF;

    -- Логика обновления
    PERFORM public.refresh_ledger();
    PERFORM public.refresh_system_ledger_report();
    
    CALL audit.sync_fullfields(NEW.id);
    
    RETURN NEW;
END;
$function$

