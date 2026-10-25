CREATE OR REPLACE FUNCTION public.update_receipts_from_transactions()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    updated_count integer;
BEGIN
    WITH transactions_agg AS (
        SELECT 
            amount, 
            operation_date, 
            array_agg(id::uuid) AS transaction_ids -- Принудительно делаем массив UUID
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
    )
    UPDATE processing.receipts r
    SET transaction_id = ta.transaction_ids
    FROM transactions_agg ta
    WHERE r.amount = ta.amount 
      AND r.operation_date = ta.operation_date 
      AND r.transaction_id IS NULL;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$function$

