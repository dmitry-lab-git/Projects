CREATE OR REPLACE FUNCTION public.fn_protect_core_ledger_columns()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Проверка состояния триггера в таблице управления
    IF NOT public.is_trigger_active('trg_protect_verified_data') THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    -- Защита исторического контура (code <= 1821)
    IF (TG_OP = 'UPDATE' AND OLD.code <= 1821) THEN
        IF (OLD.code IS DISTINCT FROM NEW.code) OR
           (OLD.legacy_code IS DISTINCT FROM NEW.legacy_code) OR
           (OLD.tr_sum IS DISTINCT FROM NEW.tr_sum) OR
           (OLD.acc_id IS DISTINCT FROM NEW.acc_id) OR
           (OLD.tr_type_id IS DISTINCT FROM NEW.tr_type_id) OR
           (OLD.operation_date IS DISTINCT FROM NEW.operation_date) OR
           (OLD.registration_date IS DISTINCT FROM NEW.registration_date) THEN
            
            RAISE EXCEPTION 'Критическая ошибка: Попытка изменения неизменяемого компонента ядра (code: %) в защищенном контуре.', OLD.code;
        END IF;
    END IF;

    -- Блокировка удаления
    IF (TG_OP = 'DELETE' AND OLD.code <= 1821) THEN
        RAISE EXCEPTION 'Критическая ошибка: Удаление записей из исторического контура (code: %) запрещено.', OLD.code;
    END IF;

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$function$

