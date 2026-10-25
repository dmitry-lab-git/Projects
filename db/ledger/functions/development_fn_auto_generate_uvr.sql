CREATE OR REPLACE FUNCTION development.fn_auto_generate_uvr()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Если код не передан, берем следующий из последовательности
    IF NEW.code IS NULL THEN
        NEW.code := nextval('development.version_updates_code_seq');
    END IF;

    -- Автоматически генерируем update_version_id (например, UVR-039, UVR-040), если он пустой
    IF NEW.update_version_id IS NULL OR NEW.update_version_id = '' THEN
        NEW.update_version_id := 'UVR-' || LPAD(NEW.code::text, 3, '0');
    END IF;

    RETURN NEW;
END;
$function$

