CREATE OR REPLACE FUNCTION public.fn_protect_migrated_transactions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Проверяем, входит ли изменяемый/удаляемый код в какой-либо закрытый интервал миграции
    IF EXISTS (
        SELECT 1 
        FROM public.sys_migration_log 
        WHERE (TG_OP = 'DELETE' AND OLD.code BETWEEN tx_code_start AND tx_code_end)
           OR (TG_OP = 'UPDATE' AND OLD.code BETWEEN tx_code_start AND tx_code_end)
    ) THEN
        RAISE EXCEPTION 'Критическая ошибка безопасности (ABS): Изменение или удаление исторической транзакции с кодом % запрещено. Данный интервал состояний зафиксирован в sys_migration_log и неизменяем.', 
            CASE WHEN TG_OP = 'DELETE' THEN OLD.code ELSE NEW.code END;
    END IF;
    
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$function$

