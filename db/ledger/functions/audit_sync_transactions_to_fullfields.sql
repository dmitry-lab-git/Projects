CREATE OR REPLACE FUNCTION audit.sync_transactions_to_fullfields()
 RETURNS TABLE(sync_report text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    rows_inserted bigint;
    start_time timestamp;
BEGIN
    start_time := clock_timestamp();

    -- 1. Удаляем триггер (если он был пересоздан или остался)
    DROP TRIGGER IF EXISTS trg_refresh_system_after_change ON audit.transactions_fullfields;

    -- 2. Очистка
    TRUNCATE TABLE audit.transactions_fullfields, audit.audit_process_queue CASCADE;

    -- 3. Наполнение (используем LEFT для защиты от ошибки длины)
    INSERT INTO audit.transactions_fullfields (
        transaction_id, transaction_name, entity_id, entity_name, 
        category_id, category_name, contragent_from_id, contragent_from_name, 
        contragent_to_id, contragent_to_name, account_id, account_name, 
        type_id, type_name, amount, tr_currency, operation_date, 
        code, acc_balance, prev_acc_tr_balance, prev_acc_tr_id, 
        transaction_code, audit_status
    )
    SELECT 
        t.id, LEFT(t.transaction_name, 512), e.entity_id, LEFT(e.entity_name, 100), 
        cat.category_id, LEFT(cat.category_name, 255), cf.contragent_id, LEFT(cf.contragent_name, 100), 
        ct.contragent_id, LEFT(ct.contragent_name, 100), a.account_id, LEFT(a.account_name, 100), 
        dt.type_id, LEFT(dt.type_name, 50), t.amount, cur.code, t.operation_date, 
        t.code, l.acc_balance, l.prev_acc_tr_balance, l.prev_acc_tr_id, 
        t.code, 'pending'
    FROM public.transactions t
    LEFT JOIN dicts.entities e ON t.entity_id = e.id
    LEFT JOIN dicts.dict_categories cat ON t.category_id = cat.id
    LEFT JOIN dicts.contragents cf ON t.contragent_from_id = cf.id
    LEFT JOIN dicts.contragents ct ON t.contragent_to_id = ct.id
    LEFT JOIN dicts.accounts a ON t.account_id = a.id
    LEFT JOIN dicts.dict_types dt ON t.type_id = dt.id
    LEFT JOIN dicts.dicts_currencies cur ON t.currency_id = cur.id
    LEFT JOIN public.ledger l ON t.id = l.transaction_uuid;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    -- 4. Наполнение очереди
    INSERT INTO audit.audit_process_queue (transaction_id, audit_status, transaction_code)
    SELECT transaction_id, 'pending', transaction_code 
    FROM audit.transactions_fullfields;

    -- 5. Формирование отчета
    sync_report := format('Sync completed. Rows processed: %s. Duration: %s.', 
                          rows_inserted, 
                          age(clock_timestamp(), start_time));
    RETURN NEXT;
END;
$function$

