CREATE OR REPLACE FUNCTION audit.post_reviewed_transactions()
 RETURNS TABLE(processed_count integer, status_message text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    inserted_rows INT := 0;
    error_msg TEXT;
    v_state TEXT;
    v_status_reviewed_id UUID;
    v_status_posted_id UUID;
    v_status_error_id UUID;
BEGIN
    -- Получаем UUID статусов из справочника dicts.dict_statuses с учетом entity_type = 'TRANSACTION'
    SELECT id INTO v_status_reviewed_id FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'REVIEWED' LIMIT 1;
    SELECT id INTO v_status_posted_id   FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'POSTED' LIMIT 1;
    SELECT id INTO v_status_error_id    FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'IMPORT_ERROR' LIMIT 1;

    -- 1. Перенос данных из staging в целевую таблицу transactions
    WITH inserted_data AS (
        INSERT INTO public.transactions (
            id, code, parent_id, transaction_name, amount, currency_id,
            operation_date, operation_time, registration_date, type_id,
            entity_id, category_id, responsible_id, contragent_from_id,
            contragent_to_id, account_id, source_extraction_id, tx_hash,
            status_id, created_at
        )
        SELECT 
            s.id,
            COALESCE(s.code, 0),
            NULL AS parent_id,
            s.transaction_name,
            s.amount,
            s.currency_id,
            s.operation_date,
            s.operation_time,
            COALESCE(s.registration_date, CURRENT_DATE),
            s.type_id,         
            s.entity_id,       
            s.category_id,   
            s.responsible_id, 
            s.contragent_from_id, 
            s.contragent_to_id,   
            s.account_id,    
            s.source_extraction_id,
            NULL AS tx_hash,
            COALESCE(v_status_posted_id, s.status_id) AS status_id,
            COALESCE(s.created_at, CURRENT_TIMESTAMP)
        FROM audit.staging_transactions s
        WHERE s.status_id = v_status_reviewed_id
        RETURNING id
    )
    SELECT COUNT(*) INTO inserted_rows FROM inserted_data;

    -- 2. Если вставка успешна, обновляем статус в staging на 'POSTED'
    IF inserted_rows > 0 THEN
        UPDATE audit.staging_transactions
        SET status_id = v_status_posted_id
        WHERE status_id = v_status_reviewed_id
          AND id IN (SELECT id FROM public.transactions);
    END IF;

    RETURN QUERY SELECT inserted_rows, 'Импорт успешно завершен'::TEXT;

EXCEPTION WHEN OTHERS THEN
    error_msg := SQLERRM;
    v_state := SQLSTATE;

    -- Проставляем статус ошибки для записей, которые не удалось импортировать
    BEGIN
        UPDATE audit.staging_transactions
        SET status_id = v_status_error_id
        WHERE status_id = v_status_reviewed_id;
    EXCEPTION WHEN OTHERS THEN
        -- Игнорируем вложенные ошибки
    END;

    RAISE EXCEPTION 'Сбой post_reviewed_transactions [SQLSTATE %]: %', v_state, error_msg;
END;
$function$

