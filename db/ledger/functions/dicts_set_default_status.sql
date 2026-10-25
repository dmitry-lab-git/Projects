CREATE OR REPLACE FUNCTION dicts.set_default_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Если status_id не был передан вручную, ищем ID для статуса 'ACTIVE'
    IF NEW.status_id IS NULL THEN
        SELECT id INTO NEW.status_id 
        FROM dicts.dict_statuses 
        WHERE entity_type = TG_TABLE_NAME 
          AND code = 'ACTIVE' 
        LIMIT 1;
    END IF;
    
    -- Возвращаем обновленную запись для вставки
    RETURN NEW;
END;
$function$

