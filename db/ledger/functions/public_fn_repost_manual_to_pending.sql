CREATE OR REPLACE FUNCTION public.fn_repost_manual_to_pending(target_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_source_id uuid;
    v_exists boolean;
BEGIN
    -- 1. Берем ID источника из правки
    SELECT source_extraction_id INTO v_source_id 
    FROM public.tx_pending_manual_confirmation 
    WHERE id = target_id;

    -- 2. Проверяем, существует ли он в основной таблице экстракции
    SELECT EXISTS(SELECT 1 FROM public.tme_tx_extraction WHERE id = v_source_id) 
    INTO v_exists;

    -- 3. Вставляем, используя NULL, если ссылка битая
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
    )
    SELECT 
        CASE WHEN v_exists THEN source_extraction_id ELSE NULL END,
        transaction_name,
        CASE 
            WHEN amount = 'nodata' OR amount IS NULL THEN 0 
            ELSE amount::numeric 
        END,
        operation_date,
        account_id,
        category_id,
        entity_id,
        tr_currency,
        'pending',
        'Manual correction: ' || COALESCE(manual_notes, 'none')
    FROM public.tx_pending_manual_confirmation
    WHERE id = target_id 
      AND status = 'need_correction';

    -- 4. Отмечаем как REPOSTED
    UPDATE public.tx_pending_manual_confirmation 
    SET status = 'REPOSTED' 
    WHERE id = target_id 
      AND status = 'need_correction';
END;
$function$

