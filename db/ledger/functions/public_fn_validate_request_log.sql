CREATE OR REPLACE FUNCTION public.fn_validate_request_log()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    status_code TEXT;
BEGIN
    -- 1. Получаем текстовый код статуса
    SELECT code INTO status_code 
    FROM dicts.dict_statuses 
    WHERE id = NEW.status_id;

    -- 2. Валидация промежуточных статусов (PENDING, SENT)
    IF status_code IN ('PENDING', 'SENT') THEN
        IF COALESCE(NEW.input_token_count, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус % требует input_token_count > 0', status_code;
        END IF;

    -- 3. Валидация успешного завершения (FINISHED)
    ELSIF status_code = 'FINISHED' THEN
        IF COALESCE(NEW.input_token_count, 0) <= 0 OR COALESCE(NEW.output_token_count, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус FINISHED требует input и output > 0';
        END IF;
        IF NEW.response_received_at IS NULL THEN
            RAISE EXCEPTION 'Статус FINISHED требует заполненного response_received_at';
        END IF;

    -- 4. Валидация пред-ошибок (генерация даже не началась)
    ELSIF status_code IN ('ERROR_GENERIC', 'ERROR_QUOTA', 'ERROR_RETRY') THEN 
        IF COALESCE(NEW.input_token_count, 0) != 0 OR COALESCE(NEW.output_token_count, 0) != 0 THEN 
            RAISE EXCEPTION 'Для системных ошибок (%) токены должны быть равны 0', status_code; 
        END IF;

    -- 5. Валидация пост-ошибок (запрос ушел, но ответ не сгенерирован)
    ELSIF status_code IN ('TIMEOUT', 'ERROR_SAFETY', 'ABANDONED') THEN 
        IF COALESCE(NEW.input_token_count, 0) <= 0 THEN 
            RAISE EXCEPTION 'Статус % означает, что запрос отправлялся, требуется input_token_count > 0', status_code; 
        END IF;
        IF COALESCE(NEW.output_token_count, 0) != 0 THEN 
            RAISE EXCEPTION 'Для статуса % output_token_count должен быть равен 0', status_code; 
        END IF;
    END IF;

    -- Пропускаем корректную запись дальше
    RETURN NEW;
END;
$function$

