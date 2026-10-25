CREATE OR REPLACE PROCEDURE audit.sync_fullfields(IN p_tx_id uuid)
 LANGUAGE plpgsql
AS $procedure$
BEGIN
    INSERT INTO audit.transactions_fullfields (
        transaction_id, transaction_name, entity_id, category_id,
        amount, operation_date, code, acc_balance, last_audited_at
    )
    SELECT 
        t.id, t.transaction_name, t.entity_id, t.category_id,
        t.amount, t.operation_date, t.code, l.acc_balance, CURRENT_TIMESTAMP
    FROM public.transactions t
    -- JOIN теперь идет строго по UUID
    LEFT JOIN public.ledger l ON t.id = l.transaction_uuid 
    WHERE t.id = p_tx_id
    ON CONFLICT (transaction_id) 
    DO UPDATE SET
        transaction_name = EXCLUDED.transaction_name,
        acc_balance      = EXCLUDED.acc_balance,
        last_audited_at  = CURRENT_TIMESTAMP;
END;
$procedure$

