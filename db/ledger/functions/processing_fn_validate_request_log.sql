CREATE OR REPLACE FUNCTION processing.fn_validate_request_log()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    status_code TEXT;
BEGIN
    SELECT code INTO status_code FROM dicts.dict_statuses WHERE id = NEW.status_id;

    -- Защита от несуществующего статуса
    IF status_code IS NULL THEN
        RAISE EXCEPTION 'Неизвестный статус ID: %', NEW.status_id;
    END IF;

    -- Валидация (используем имена полей из api_requests_log)
    IF status_code IN ('PENDING', 'SENT') THEN
        IF COALESCE(NEW.input_tokens, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус % требует input_tokens > 0', status_code;
        END IF;

    ELSIF status_code = 'FINISHED' THEN
        IF COALESCE(NEW.input_tokens, 0) <= 0 OR COALESCE(NEW.output_tokens, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус FINISHED требует input и output > 0';
        END IF;
        -- Примечание: в текущем DDL api_requests_log нет поля response_received_at, 
        -- поэтому проверку для него убираем, чтобы не падало с ошибкой.

    ELSIF status_code IN ('ERROR_GENERIC', 'ERROR_QUOTA', 'ERROR_RETRY') THEN 
        IF COALESCE(NEW.output_tokens, 0) != 0 THEN 
            RAISE EXCEPTION 'Для системных ошибок (%) выходные токены должны быть 0', status_code; 
        END IF;

    ELSIF status_code IN ('TIMEOUT', 'ERROR_SAFETY', 'ABANDONED') THEN 
        IF COALESCE(NEW.input_tokens, 0) <= 0 THEN 
            RAISE EXCEPTION 'Статус % требует input_tokens > 0', status_code; 
        END IF;
        IF COALESCE(NEW.output_tokens, 0) != 0 THEN 
            RAISE EXCEPTION 'Для статуса % output_tokens должен быть 0', status_code; 
        END IF;
    END IF;

    RETURN NEW;
END;
$function$

