CREATE OR REPLACE FUNCTION public.fn_repost_manual_to_posting(target_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_source_id uuid;
    -- Объявляем переменные для всех полей
    v_rec RECORD;
BEGIN
    -- 1. Берем данные конкретной записи
    SELECT * INTO v_rec 
    FROM public.tx_pending_manual_confirmation 
    WHERE id = target_id 
      AND status = 'need_correction';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Запись % не найдена или статус не need_correction', target_id;
    END IF;

    -- 2. Вставляем, явно указывая source_extraction_id
    INSERT INTO public.tx_pending_posting (
        source_extraction_id,
        transaction_name,
        amount,
        operation_date,
        account_id,
        category_id,
        entity_id,
        tr_currency,
        status,
        review_notes
    ) VALUES (
        v_rec.source_extraction_id, -- Явное использование переменной
        v_rec.transaction_name,
        CASE WHEN v_rec.amount = 'nodata' OR v_rec.amount IS NULL THEN 0 ELSE v_rec.amount::numeric END,
        v_rec.operation_date,
        v_rec.account_id,
        v_rec.category_id,
        v_rec.entity_id,
        v_rec.tr_currency,
        'pending',
        'Manual correction: ' || COALESCE(v_rec.manual_notes, 'none')
    );

    -- 3. Обновляем статус
    UPDATE public.tx_pending_manual_confirmation 
    SET status = 'REPOSTED' 
    WHERE id = target_id;
END;
$function$

