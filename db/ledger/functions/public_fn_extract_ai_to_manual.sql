CREATE OR REPLACE FUNCTION public.fn_extract_ai_to_manual()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO public.tx_pending_manual_confirmation (
        source_extraction_id, transaction_name, operation_date, operation_time,
        category_id, category_name, entity_id, entity_name,
        contragent_from_id, contragent_from_name, contragent_to_id, contragent_to_name,
        account_id, account_name, type_id, type_name,
        amount, tr_currency, ai_conclusion, sort_order
    )
    SELECT 
        src.tx_validation_id,
        (src.ai_verdict_json->>'transaction_name'),
        (src.ai_verdict_json->>'operation_date')::date,
        (src.ai_verdict_json->>'operation_time')::time,
        COALESCE(src.ai_verdict_json->>'category_id', 'needreview'),
        (SELECT category_name FROM public.dict_categories WHERE category_id = src.ai_verdict_json->>'category_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'entity_id', 'needreview'),
        (SELECT entity_name FROM public.entities WHERE entity_id = src.ai_verdict_json->>'entity_id' LIMIT 1),
        (src.ai_verdict_json->>'contragent_from_id'),
        (SELECT contragent_name FROM public.contragents WHERE cnaid = src.ai_verdict_json->>'contragent_from_id' LIMIT 1),
        (src.ai_verdict_json->>'contragent_to_id'),
        (SELECT contragent_name FROM public.contragents WHERE cnaid = src.ai_verdict_json->>'contragent_to_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'account_id', 'needreview'),
        (SELECT account_name FROM public.accounts WHERE account_id = src.ai_verdict_json->>'account_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'type_id', 'needreview'),
        (SELECT type_name FROM public.dict_types WHERE type_id = src.ai_verdict_json->>'type_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'amount', 'nodata'),
        COALESCE(src.ai_verdict_json->>'tr_currency', 'KZT'),
        (src.ai_verdict_json->>'conclusion'),
        ROW_NUMBER() OVER (ORDER BY (src.ai_verdict_json->>'operation_date')::date ASC, 
                           COALESCE((src.ai_verdict_json->>'operation_time')::time, '00:00:00') ASC)
    FROM public.tx_pending_validation src
    WHERE src.status = 'PENDING';

    UPDATE public.tx_pending_validation SET status = 'PROCESSED' WHERE status = 'PENDING';
END;
$function$

