CREATE OR REPLACE FUNCTION public.update_receipts_contragent_by_amount()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    updated_count integer;
BEGIN
    WITH unique_mapping AS (
        SELECT amount, operation_date, MIN(contragent_to_id::text)::uuid AS contragent_to_id
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
        HAVING COUNT(DISTINCT contragent_to_id) = 1
    )
    UPDATE processing.receipts r
    SET contragent_id = um.contragent_to_id
    FROM unique_mapping um
    WHERE r.amount = um.amount
      AND r.operation_date = um.operation_date
      AND r.contragent_id IS NULL;
      
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$function$

