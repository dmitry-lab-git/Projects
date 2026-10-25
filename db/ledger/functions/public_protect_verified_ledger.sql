CREATE OR REPLACE FUNCTION public.protect_verified_ledger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Защищаем весь проверенный исторический контур (с 1 по 1821 строки)
    IF (TG_OP = 'DELETE' AND OLD.code <= 1821) OR 
       (TG_OP = 'UPDATE' AND OLD.code <= 1821) THEN
        RAISE EXCEPTION 'Критическая ошибка: Попытка изменения защищенного исторического контура (строки 1-1821). Операция заблокирована.';
    END IF;
    RETURN NEW;
END;
$function$

